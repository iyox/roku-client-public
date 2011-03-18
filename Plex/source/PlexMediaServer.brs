'*
'* Facade to a PMS server responsible for fetching PMS meta-data and
'* formatting into Roku format as well providing the interface to the
'* streaming media
'* 

'* Constructor for a specific PMS instance identified via the URL and 
'* human readable name, which can be used in section names
Function newPlexMediaServer(pmsUrl, pmsName) As Object
	pms = CreateObject("roAssociativeArray")
	pms.serverUrl = pmsUrl
	pms.name = pmsName
	pms.GetContent = directoryContent
	pms.GetHomePageContent = homePageContent
	pms.GetListNames = listNames
	pms.GetListKeys = listKeys
	pms.VideoScreen = constructVideoScreen
	pms.PluginVideoScreen = constructPluginVideoScreen
	pms.StopVideo = stopTranscode
	pms.GetQueryResponse = xmlContent
	pms.GetPaginatedQueryResponse = paginatedXmlContent
	pms.ConstructDirectoryMetadata = ConstructDirectoryMetadata
	pms.ConstructVideoMetadata = ConstructVideoMetadata
	pms.ConstructTrackMetadata = ConstructTrackMetadata
	pms.DetailedVideoMetadata = videoMetadata
	pms.SetProgress = progress
	pms.Scrobble = scrobble
	pms.Unscrobble = unscrobble
	pms.Rate = rate
	pms.ExecuteCommand = issueCommand
	pms.ExecutePostCommand = issuePostCommand
	pms.UpdateAudioStreamSelection = updateAudioStreamSelection
	pms.UpdateSubtitleStreamSelection = updateSubtitleStreamSelection
	return pms
End Function

'* This needs a HTTP PUT command that does not exist in the Roku API but it's faked with a POST
Function updateAudioStreamSelection(partId As String, audioStreamId As String)
	commandUrl = "/library/parts/"+partId+"?audioStreamID="+audioStreamId
	m.ExecutePostCommand(commandUrl)
End Function

Function updateSubtitleStreamSelection(partId As String, subtitleStreamId As String)
	subtitle = invalid
	if subtitleStreamId <> invalid then
		subtitle = subtitleStreamId
	endif
	commandUrl = "/library/parts/"+partId+"?subtitleStreamID="+subtitle
	m.ExecutePostCommand(commandUrl)
End Function

Function issuePostCommand(commandPath)
	commandUrl = m.serverUrl + commandPath
	print "Executing POST command with full command URL:";commandUrl
	request = CreateObject("roUrlTransfer")
	request.SetUrl(commandUrl)
	request.PostFromString("")
End Function

Function progress(key, identifier, time)
	commandUrl = "/:/progress?key="+key+"&identifier="+identifier+"&time="+time.tostr()
	m.ExecuteCommand(commandUrl)
End Function

Function scrobble(key, identifier)
	commandUrl = "/:/scrobble?key="+key+"&identifier="+identifier
	m.ExecuteCommand(commandUrl)
End Function

Function unscrobble(key, identifier)
	commandUrl = "/:/unscrobble?key="+key+"&identifier="+identifier
	m.ExecuteCommand(commandUrl)
End Function

Function rate(key, identifier, rating)
	commandUrl = "/:/rate?key="+key+"&identifier="+identifier+"&rating="+rating
	m.ExecuteCommand(commandUrl)
End Function

Function issueCommand(commandPath)
	commandUrl = m.serverUrl + commandPath
	print "Executing command with full command URL:";commandUrl
	request = CreateObject("roUrlTransfer")
	request.SetUrl(commandUrl)
	request.GetToString()
End Function

Function homePageContent() As Object
	xml = m.GetQueryResponse("", "/library/sections")
	librarySections = m.GetContent(xml)
	content = CreateObject("roArray", librarySections.Count() + 1, true)
	for each section in librarySections
		content.Push(section)
	next
	'* TODO: only add this if we actually have any valid apps?
	appsSection = CreateObject("roAssociativeArray")
	appsSection.server = m
    appsSection.sourceUrl = ""
	appsSection.ContentType = "series"
	appsSection.Key = "apps"
	appsSection.Title = "Channels"
	appsSection.ShortDescriptionLine1 = "Channels"
	appsSection.SDPosterURL = "file://pkg:/images/plex.png"
	appsSection.HDPosterURL = "file://pkg:/images/plex.png"
	content.Push(appsSection)
	return content
End Function

'* Detailed video meta-data for springboard screen
Function videoMetadata(sourceUrl, key) As Object
	xmlResponse = m.GetQueryResponse(sourceUrl, key)
	videoItem = xmlResponse.xml.Video[0]
	video = CreateObject("roAssociativeArray")
	video.server = m
	video.mediaContainerIdentifier = xmlResponse.xml@identifier
	video.sourceUrl = sourceUrl
	video.ratingKey = videoItem@ratingKey
	video.ContentType = videoItem@type
	video.Title = videoItem@title
	video.Key = videoItem@key
	video.ShortDescriptionLine1 = videoItem@title
	video.ShortDescriptionLine2 = videoItem@tagline
	video.Description = videoItem@summary
	video.Rating = videoItem@contentRating
	video.ReleaseDate = videoItem@originallyAvailableAt
	video.viewOffset = videoItem@viewOffset
	video.viewCount = videoItem@viewCount
	
	if video.ContentType = "episode" then
		video.EpisodeNumber = videoItem@index
	endif
	length = videoItem@duration
	if length <> invalid then
		video.Length = int(val(length)/1000)
	endif
	rating = videoItem@rating
	if rating <> invalid then
		video.StarRating = int(val(rating)*10)
	endif
	video.Actors = CreateObject("roArray", 15, true)
	for each Actor in videoItem.Role
		video.Actors.Push(Actor@tag)
	next
	video.Director = CreateObject("roArray", 3, true)
	for each Director in videoItem.Director
		video.Director.Push(Director@tag)
	next
	video.Categories = CreateObject("roArray", 15, true)
	for each Category in videoItem.Genre
		video.Categories.Push(Category@tag)
	next
	
	sizes = ImageSizes("movie", video.ContentType)
	thumb = videoItem@thumb
	if thumb <> invalid then
		video.SDPosterURL = TranscodedImage(m.serverUrl, sourceUrl, thumb, sizes.sdWidth, sizes.sdHeight)
		video.HDPosterURL = TranscodedImage(m.serverUrl, sourceUrl, thumb, sizes.hdWidth, sizes.hdHeight)
	else
		art = videoItem@art
		if art = invalid then
			art = xml@art
		endif
		if art <> invalid then
			video.SDPosterURL = TranscodedImage(m.serverUrl, sourceUrl, art, sizes.sdWidth, sizes.sdHeight)
			video.HDPosterURL = TranscodedImage(m.serverUrl, sourceUrl, art, sizes.hdWidth, sizes.hdHeight)	
		endif
	endif
	
	video.IsHD = False
	video.HDBranded = False
	video.media = CreateObject("roArray", 5, true)
	for each MediaItem in videoItem.Media
		media = CreateObject("roAssociativeArray")
		media.identifier = MediaItem@id
		media.audioCodec = MediaItem@audioCodec
		media.videoCodec = MediaItem@videoCodec
		media.videoResolution = MediaItem@videoResolution
		if media.videoResolution = "1080" OR media.videoResolution = "720" then
			video.IsHD = True
			video.HDBranded = True
		endif
		if media.videoResolution = "1080" then
			video.FullHD = true
			frameRate = MediaItem@videoFrameRate
			if frameRate = "24p" then
				video.FrameRate = 24
			else if frameRate = "NTSC"
				video.FrameRate = 30
			endif
		endif
		media.container = MediaItem@container
		media.parts = CreateObject("roArray", 3, true)
		for each MediaPart in MediaItem.Part
			part = CreateObject("roAssociativeArray")
			part.id = MediaPart@id
			part.key = MediaPart@key
			part.streams = CreateObject("roArray", 5, true)
			for each StreamItem in MediaPart.Stream
				stream = CreateObject("roAssociativeArray")
				stream.id = StreamItem@id
				stream.streamType = StreamItem@streamType
				stream.codec = StreamItem@codec
				stream.language = StreamItem@language
				stream.selected = StreamItem@selected
				stream.channels = StreamItem@channels
				part.streams.Push(stream)
			next
			media.parts.Push(part)
		next
		'* TODO: deal with multiple parts correctly. Not sure how audio etc selection works
		'* TODO: with multi-part
		media.preferredPart = media.parts[0]
		video.media.Push(media)
	next
	return video
End Function

Function paginatedXmlContent(sourceUrl, key, start, size) As Object

	xmlResult = CreateObject("roAssociativeArray")
	xmlResult.server = m
	if key = "apps" then
		'* Fake a minimal server response with a new viewgroup
		xml=CreateObject("roXMLElement")
		xml.Parse("<MediaContainer viewgroup='apps'/>")
		xmlResult.xml = xml
		xmlResult.sourceUrl = invalid
	else
			queryUrl = FullUrl(m.serverUrl, sourceUrl, key)
			response = paginatedQuery(queryUrl, start, size)
			xml=CreateObject("roXMLElement")
			if not xml.Parse(response) then
				print "Can't parse feed:";response
			endif
			xmlResult.xml = xml
			xmlResult.sourceUrl = queryUrl
	endif
	return xmlResult
End Function

Function paginatedQuery(queryUrl, start, size) As Object
	print "Fetching content from server at query URL:";queryUrl
	print "Pagination start:";start.tostr()
	print "Pagination size:";size.tostr()
	httpRequest = NewHttp(queryUrl)
	httpRequest.Http.AddHeader("X-Plex-Container-Start", start.tostr())
	httpRequest.Http.AddHeader("X-Plex-Container-Size", size.tostr())
	response = httpRequest.GetToStringWithRetry()
	return response
End Function

Function xmlContent(sourceUrl, key) As Object

	xmlResult = CreateObject("roAssociativeArray")
	xmlResult.server = m
	if key = "apps" then
		'* Fake a minimal server response with a new viewgroup
		xml=CreateObject("roXMLElement")
		xml.Parse("<MediaContainer viewgroup='apps'/>")
		xmlResult.xml = xml
		xmlResult.sourceUrl = invalid
	else
		queryUrl = FullUrl(m.serverUrl, sourceUrl, key)
		print "Fetching content from server at query URL:";queryUrl
		httpRequest = NewHttp(queryUrl)
		response = httpRequest.GetToStringWithRetry()
		xml=CreateObject("roXMLElement")
		if not xml.Parse(response) then
			print "Can't parse feed:";response
		endif
			
		xmlResult.xml = xml
		xmlResult.sourceUrl = queryUrl
	endif
	return xmlResult
End Function

Function listNames(parsedXml) As Object
	content = CreateObject("roArray", 10, true)
	if parsedXml.xml@viewGroup = "apps" then
		content.Push("Video")
		content.Push("Audio")
		content.Push("Photo")
	else
		sectionViewGroup = parsedXml.xml@viewGroup
		if sectionViewGroup = "secondary" then
			sections = m.GetContent(parsedXml)
			for each section in sections
				content.Push(section.title)
			next
		endif
	endif
	return content
End Function

Function listKeys(parsedXml) As Object
	content = CreateObject("roArray", 10, true)
	if parsedXml.xml@viewGroup = "apps" then
		content.Push("/video")
		content.Push("/music")
		content.Push("/photos")
	else
		sectionViewGroup = parsedXml.xml@viewGroup
		if sectionViewGroup = "secondary" then
			sections = m.GetContent(parsedXml)
			for each section in sections
				content.Push(section.key)
			next
		endif
	endif
	return content
End Function
		
Function directoryContent(parsedXml) As Object
	content = CreateObject("roArray", 11, true)
	for each directoryItem in parsedXml.xml.Directory
		if directoryItem@search = invalid then
			directory = m.ConstructDirectoryMetadata(parsedXml.xml, directoryItem, parsedXml.sourceUrl)
			content.Push(directory)
		endif
	next
	for each videoItem in parsedXml.xml.Video
		video = m.ConstructVideoMetadata(parsedXml.xml, videoItem, parsedXml.sourceUrl)
		content.Push(video)
	next
	for each trackItem in parsedXml.xml.Track
		track = m.ConstructTrackMetadata(parsedXml.xml, trackItem, parsedXml.sourceUrl)
		content.Push(track)
	next
	print "Found a content list with elements";content.count()
	return content
End Function

Function ConstructDirectoryMetadata(xml, directoryItem, sourceUrl) As Object	
	directory = CreateObject("roAssociativeArray")
	directory.server = m
	directory.sourceUrl = sourceUrl
	directory.ContentType = directoryItem@type
	if directory.ContentType = "show" then
		directory.ContentType = "series"
	else if directory.ContentType = invalid then
		directory.ContentType = "appClip"
	endif
	directory.Key = directoryItem@key
	directory.Title = directoryItem@title
	directory.Description = directoryItem@summary
	if directory.Title = invalid then
		directory.Title = directoryItem@name
	endif
	directory.ShortDescriptionLine1 = directoryItem@title
	if directory.ShortDescriptionLine1 = invalid then
		directory.ShortDescriptionLine1 = directoryItem@name
	endif
	
	sizes = ImageSizes(xml@viewGroup, directory.ContentType)
	thumb = directoryItem@thumb
	if thumb <> invalid then
		directory.SDPosterURL = TranscodedImage(m.serverUrl, sourceUrl, thumb, sizes.sdWidth, sizes.sdHeight)
		directory.HDPosterURL = TranscodedImage(m.serverUrl, sourceUrl, thumb, sizes.hdWidth, sizes.hdHeight)
	else
		art = directoryItem@art
		if art = invalid then
			art = xml@art
		endif
		if art <> invalid then
			directory.SDPosterURL = TranscodedImage(m.serverUrl, sourceUrl, art, sizes.sdWidth, sizes.sdHeight)
			directory.HDPosterURL = TranscodedImage(m.serverUrl, sourceUrl, art, sizes.hdWidth, sizes.hdHeight)
		endif
	endif
	return directory
End Function
		
Function ConstructVideoMetadata(xml, videoItem, sourceUrl) As Object
	video = CreateObject("roAssociativeArray")
	video.server = m
	video.sourceUrl = sourceUrl
	video.ratingKey = videoItem@ratingKey
	video.ContentType = videoItem@type
	if video.ContentType = invalid then
		'* treat video items with no content type as clips
		video.ContentType = "clip" 
	endif
	video.Title = videoItem@title
	video.Key = videoItem@key
	video.ShortDescriptionLine1 = videoItem@title
	video.ShortDescriptionLine2 = videoItem@tagline
	if xml@viewGroup = "episode" then
		video.ShortDescriptionLine2 = videoItem@grandparentTitle
		if video.ShortDescriptionLine2 = invalid then
			video.ShortDescriptionLine2 = "Episode "+videoItem@index
		endif
	endif
	if xml@viewGroup = "Details" then
		video.ShortDescriptionLine2 = videoItem@summary
	endif
	video.Description = videoItem@summary
	
	sizes = ImageSizes(xml@viewGroup, video.ContentType)
	thumb = videoItem@thumb
	if thumb <> invalid then
		video.SDPosterURL = TranscodedImage(m.serverUrl, sourceUrl, thumb, sizes.sdWidth, sizes.sdHeight)
		video.HDPosterURL = TranscodedImage(m.serverUrl, sourceUrl, thumb, sizes.hdWidth, sizes.hdHeight)
	else
		art = videoItem@art
		if art = invalid then
			art = xml@art
		endif
		if art <> invalid then
			video.SDPosterURL = TranscodedImage(m.serverUrl, sourceUrl, art, sizes.sdWidth, sizes.sdHeight)
			video.HDPosterURL = TranscodedImage(m.serverUrl, sourceUrl, art, sizes.hdWidth, sizes.hdHeight)	
		endif
	endif
	return video
End Function


'* This logic reflects that in the PosterScreen.SetListStyle
'* Not using the standard sizes appears to slow navigation down
Function ImageSizes(viewGroup, contentType) As Object
	'* arced-square size	
	sdWidth = "223"
	sdHeight = "200"
	hdWidth = "300"
	hdHeight = "300"
	if viewGroup = "movie" OR viewGroup = "show" OR viewGroup = "season" OR viewGroup = "episode" then
	'* arced-portrait sizes
		sdWidth = "158"
		sdHeight = "204"
		hdWidth = "214"
		hdHeight = "306"
	elseif contentType = "episode" AND viewGroup = "episode" then
		'* flat-episodic sizes
		sdWidth = "166"
		sdHeight = "112"
		hdWidth = "224"
		hdHeight = "168"
	elseif viewGroup = "Details" then
		'* arced-square sizes
		sdWidth = "223"
		sdHeight = "200"
		hdWidth = "300"
		hdHeight = "300"
	
	endif
	sizes = CreateObject("roAssociativeArray")
	sizes.sdWidth = sdWidth
	sizes.sdHeight = sdHeight
	sizes.hdWidth = hdWidth
	sizes.hdHeight = hdHeight
	return sizes
End Function

'* TODO: music is not fully developed
Function ConstructTrackMetadata(xml, trackItem, sourceUrl) As Object
	track = CreateObject("roAssociativeArray")
	track.server = m
	track.sourceUrl = sourceUrl
	track.ContentType = trackItem@type
	track.Title = trackItem@title
	track.Key = trackItem@key
	track.ShortDescriptionLine1 = trackItem@title
		'* TODO: need a way to choose between media options and concat parts
	track.mediaKey = trackItem.Media.Part@Key
		
		'* Use parent
		'track.ShortDescriptionLine2 = trackItem@tagline
		'thumb = videoItem@thumb
		'video.SDPosterURL = TranscodedImage(m.serverUrl, queryUrl, thumb, "158", "204")
		'video.HDPosterURL = TranscodedImage(m.serverUrl, queryUrl, thumb, "214", "306")
	return track
End Function
		
Function constructPluginVideoScreen(metadata) As Object
    print "Constructing video screen for ";metadata.key
    p = CreateObject("roMessagePort")
    video = CreateObject("roVideoScreen")
    video.setMessagePort(p)
    videoclip = ConstructVideoClip(m.serverUrl, metadata.key, metadata.sourceUrl, "", "", metadata.title)
    video.SetContent(videoclip)
    m.Cookie = StartTranscodingSession(videoclip.StreamUrls[0])
	video.AddHeader("Cookie", m.Cookie)
	return video
End Function

'* TODO: this assumes one part media. Implement multi-part at some point.
'* TODO: currently always transcodes. Check direct stream codecs first.
Function constructVideoScreen(metadata, mediaData, StartTime As Integer) As Object
	mediaPart = mediaData.preferredPart
	mediaKey = mediaPart.key
    print "Constructing video screen for ";mediaKey
    p = CreateObject("roMessagePort")
    video = CreateObject("roVideoScreen")
    video.setMessagePort(p)
    videoclip = ConstructVideoClip(m.serverUrl, mediaKey, metadata.sourceUrl, metadata.ratingKey, metadata.key, metadata.title)
    videoclip.PlayStart = StartTime
    video.SetContent(videoclip)
    m.Cookie = StartTranscodingSession(videoclip.StreamUrls[0])
	video.AddHeader("Cookie", m.Cookie)
	return video
End Function

Function stopTranscode()
	stopTransfer = CreateObject("roUrlTransfer")
    stopTransfer.SetUrl(m.serverUrl + "/video/:/transcode/segmented/stop")
    stopTransfer.AddHeader("Cookie", m.Cookie) 
    content = stopTransfer.GetToString()
End Function


'* Constructs a Full URL taking into account relative/absolute. Relative to the 
'* source URL, and absolute URLs, so
'* relative to the server URL
Function FullUrl(serverUrl, sourceUrl, key) As String
    'print "ServerURL:";serverUrl
    'print "SourceURL:";sourceUrl
    'print "Key:";key
	finalUrl = ""
	if left(key, 4) = "http" then
	    finalUrl = key
	else if key = "" AND sourceUrl = "" then
	    finalUrl = serverUrl
    else if key = "" AND serverUrl = "" then
        finalUrl = sourceUrl
	else if left(key, 1) = "/" then
		finalUrl = serverUrl+key
	else
		finalUrl = sourceUrl+"/"+key
	endif
    'print "FinalURL:";finalUrl
	return finalUrl
End Function

'* Constructs an image based on a PMS url with the specific width and height. 
Function TranscodedImage(serverUrl, queryUrl, imagePath, width, height) As String
	imageUrl = FullUrl(serverUrl, queryUrl, imagePath)
	encodedUrl = HttpEncode(imageUrl)
	image = serverUrl + "/photo/:/transcode?url="+encodedUrl+"&width="+width+"&height="+height
	'print "Final Image URL:";image
	return image
End Function


'* Starts a transcoding session by issuing a HEAD request and captures
'* the resultant session ID from the cookie that can then be used to
'* access and stop the transcoding
Function StartTranscodingSession(videoUrl) As String
	cookiesRequest = CreateObject("roUrlTransfer")
	cookiesRequest.SetUrl(videoUrl)
	capabilities = "protocols=http-streaming-video;http-streaming-video-720p;videoDecoders=h264{profile:high&resolution:1080&level:40};audioDecoders=aac"
	cookiesRequest.AddHeader("X-Plex-Client-Capabilities", capabilities)
	cookiesHead = cookiesRequest.Head()
	cookieHeader = cookiesHead.GetResponseHeaders()["set-cookie"]
	return cookieHeader
End Function

'* Roku video clip definition as an array
Function ConstructVideoClip(serverUrl as String, videoUrl as String, sourceUrl As String, ratingKey As String, key As String, title as String) As Object
	deviceInfo = CreateObject("roDeviceInfo")
	quality = "SD"
	if deviceInfo.GetDisplayType() = "HDTV" then
		quality = "HD"
	endif
	print "Setting stream quality:";quality
	videoclip = CreateObject("roAssociativeArray")
    videoclip.StreamBitrates = [0]
    videoclip.StreamUrls = [TranscodingVideoUrl(serverUrl, videoUrl, sourceUrl, ratingKey, key)]
    videoclip.StreamQualities = [quality]
    videoclip.StreamFormat = "hls"
    videoclip.Title = title
    return videoclip
End Function

'*
'* Construct the Plex transcoding URL. 
'*
Function TranscodingVideoUrl(serverUrl As String, videoUrl As String, sourceUrl As String, ratingKey As String, key As String) As String
    print "Constructing transcoding video URL for "+videoUrl
    '* Deal with absolute, full then relative URLs - TODO DRY:move to own function
    if left(videoUrl, 1) = "/" then
    	location = serverUrl + videoUrl 
    else if left(videoUrl, 7) = "http://"
    	location = videoUrl
    else
    	location = sourceUrl + "/" + videoUrl
    endif
    print "Location:";location
    if left(key, 1) = "/" then
    	fullKey = serverUrl + key 
    else if left(key, 7) = "http://"
    	fullKey = key
    else
    	fullKey = sourceUrl + "/" + key
    endif
    print "Full key:";fullKey
    
    
    '* Question here about how the quality is handled by Roku for q>6 (playback baulked at q>6). 
    '* More recent testing: it now appears to work fine with 7,8 and 9 but baulks at 10. It also
    '* appears to be able to handle the bitrate at q=9, even though it's way over spec.
    '*
    '* Take that back. 1080p no transcoding at q=9 is not good.
    '*
    '* Only difference (other than PMS) was wireless vs wired. Maybe Roku can detect upper end of network bandwidth
    '* capabilities and rejects streams above that?
    '*
    '* Put min and max and let Roku choose? Shouldn't (yeah, right) bounce after initial selection as we're on local network
    '* 
    myurl = "/video/:/transcode/segmented/start.m3u8?identifier=com.plexapp.plugins.library&ratingKey="+ratingKey+"&key="++HttpEncode(fullKey)+"&offset=0&quality=8&url="+HttpEncode(location)+"&3g=0&httpCookies=&userAgent="
	'myurl = "/video/:/transcode/segmented/start.m3u8?identifier=com.plexapp.plugins.library&ratingKey=97007888&offset=0&minQuality=5&maxQuality=8&url="+HttpEncode(location)+"&3g=0&httpCookies=&userAgent="
	publicKey = "KQMIY6GATPC63AIMC4R2"
	time = LinuxTime().tostr()
	msg = myurl+"@"+time
	finalMsg = HMACHash(msg)
	finalUrl = serverUrl + myurl+"&X-Plex-Access-Key=" + publicKey + "&X-Plex-Access-Time=" + time + "&X-Plex-Access-Code=" + HttpEncode(finalMsg)
	print "Final URL:";finalUrl
    return finalUrl
End Function

'*
'* HMAC encode the message
'* 
Function HMACHash(msg As String) As String
	hmac = CreateObject("roHMAC") 
	privateKey = CreateObject("roByteArray") 
	privateKey.fromBase64String("k3U6GLkZOoNIoSgjDshPErvqMIFdE0xMTx8kgsrhnC0=")
	result = hmac.setup("sha256", privateKey)
	if result = 0
		message = CreateObject("roByteArray") 
		message.fromAsciiString(msg) 
		result = hmac.process(message)
		return result.toBase64String()
	end if
End Function

'*
'* Time since the start (of UNIX time)
'*
Function LinuxTime() As Integer
	time = CreateObject("roDateTime")
	return time.asSeconds()
End Function


REM ******************************************************
REM Constucts a URL Transfer object
REM ******************************************************

Function CreateURLTransferObject(url As String) as Object
    obj = CreateObject("roUrlTransfer")
    obj.SetPort(CreateObject("roMessagePort"))
    obj.SetUrl(url)
    obj.AddHeader("Content-Type", "application/x-www-form-urlencoded")
	obj.AddHeader("X-Plex-Version", "0.9") '* Correct ?
	obj.AddHeader("X-Plex-Language", "en") '* Anyway to get this from the platform ?
	obj.AddHeader("X-Plex-Client-Platform", "Roku")
    obj.EnableEncodings(true)
    return obj
End Function

REM ******************************************************
REM Url Query builder
REM so this is a quick and dirty name/value encoder/accumulator
REM ******************************************************

Function NewHttp(url As String) as Object
    obj = CreateObject("roAssociativeArray")
    obj.Http                        = CreateURLTransferObject(url)
    obj.FirstParam                  = true
    obj.AddParam                    = http_add_param
    obj.AddRawQuery                 = http_add_raw_query
    obj.GetToStringWithRetry        = http_get_to_string_with_retry
    obj.PrepareUrlForQuery          = http_prepare_url_for_query
    obj.GetToStringWithTimeout      = http_get_to_string_with_timeout
    obj.PostFromStringWithTimeout   = http_post_from_string_with_timeout

    if Instr(1, url, "?") > 0 then obj.FirstParam = false

    return obj
End Function


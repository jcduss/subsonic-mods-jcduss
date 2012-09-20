<%@ page language="java" contentType="text/html; charset=utf-8" pageEncoding="iso-8859-1"%>
<!DOCTYPE html PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN" "http://www.w3.org/TR/html4/loose.dtd">
<html><head>
    <%@ include file="head.jsp" %>
    <script type="text/javascript" src="<c:url value="/dwr/interface/nowPlayingService.js"/>"></script>
    <script type="text/javascript" src="<c:url value="/dwr/interface/playlistService.js"/>"></script>
    <script type="text/javascript" src="<c:url value="/dwr/engine.js"/>"></script>
    <script type="text/javascript" src="<c:url value="/dwr/util.js"/>"></script>
    <script type="text/javascript" src="<c:url value="/script/prototype.js"/>"></script>
    <script type="text/javascript" src="<c:url value="/script/scripts.js"/>"></script>
    <script type="text/javascript" src="<c:url value="/script/swfobject.js"/>"></script>
    <script type="text/javascript" src="<c:url value="/script/webfx/range.js"/>"></script>
    <script type="text/javascript" src="<c:url value="/script/webfx/timer.js"/>"></script>
    <script type="text/javascript" src="<c:url value="/script/webfx/slider.js"/>"></script>
    <link type="text/css" rel="stylesheet" href="<c:url value="/script/webfx/luna.css"/>">
</head>

<body class="bgcolor2 playlistframe" onload="init()">

<script type="text/javascript" language="javascript"><!--
    var player = null;
    var songs = null;
    var currentAlbumUrl = null;
    var currentStreamUrl = null;
    var startPlayer = false;
    var repeatEnabled = false;
    var slider = null;

    /// Start VLC IMplementation
	// Logics:
	//	- on the server side, a VLC player is handled like an external with pl
	//  - on the client side, a VLC player is similar to the web player
	// TODOS : replace choose/when/otherwis with js var = model.play.WEB, check if vlc player is online
	// REDESIGN play/stop/volume control  
    var vlcPlayer = ${model.player.VLC};
    var vlcAction = "";
    var vlcSongsCount = 0;
    var vlc_url = "${model.player.vlcUrl}";
    
    var vlcGainFactor = 800; // VLC volume is max 1024
	var vlcTranslateUrl = false; //depends on version
	var vlcMoveEnabled = true;
   	//var vlcWasOnline = false; //abandonned, 
    var vlcSsiVolume;
    var vlcKnownVolume;
    var vlcSsiState = "";
    var vlcKnownState = "";
    var vlcSsiPos = 0;
    var vlcSsiID = new Array();
    var vlcSsiCurrID;
    var vlcSsiVersion = "";
    
    function addslashes( str ){ return str.replace(/\'/g, '\\\''); }
	function escapebackslashes( str ){ return str.replace(/\\/g, '\\\\'); }	
    function vlcGet(req_url){
        // continue only if vlc techno
       <c:if test="${model.player.VLC}">
	    	// Translate old commands into new ones
	    	var args = arguments;
	    	if ( req_url.indexOf("?control") == 0 && vlcTranslateUrl) {
				if (req_url.indexOf("move") >= 0 ) {
					// not supported on newer versions
					req_url = "";
				} else if (req_url.indexOf("control=delete") >= 0 ) {
					req_url = "requests/status.xml?command=pl_delete&id=" + arguments[1];
				} else if (req_url.indexOf("control=volume") >= 0 ) {
					req_url = "requests/status.xml?command=volume&val=" + arguments[1];					
				}
				// add
				// "?control=add&mrl=" + encodeURIComponent( addslashes(escapebackslashes(songs[i].streamUrl + "&suffix=.mp3"))) + "&name=" + encodeURIComponent(songs[i].title);
		        // becomes "requests/status.xml?command=in_enqueue&input=" + encodeURIComponent( addslashes(escapebackslashes(songs[i].streamUrl + "&suffix=.mp3"));				
		         	
		    }
		    // Concatenate old style command and argument
			if (arguments[1] != undefined && !vlcTranslateUrl) {
				req_url = req_url + arguments[1];
			}
			
	    	if ( req_url != "" ) {
		    	var ajaxRequest;  // The variable that makes Ajax possible!
		    	
		    	try{
		    		// Opera 8.0+, Firefox, Safari
		    		ajaxRequest = new XMLHttpRequest();
		    	} catch (e){
		    		// Internet Explorer Browsers
		    		try{
		    			ajaxRequest = new ActiveXObject("Msxml2.XMLHTTP");
		    		} catch (e) {
		    			try{
		    				ajaxRequest = new ActiveXObject("Microsoft.XMLHTTP");
		    			} catch (e){
		    				// Something went wrong
		    				alert("Cannot communicate with VLC player!");
		    				return false;
		    			}
		    		}
		    	}
		    		
		    	// add timestamp to url to prevent caching
		    	var timestamp =  new Date;
		    	ajaxRequest.open("GET", vlc_url + req_url + "&" + timestamp.getTime(), true);
		    	try {
		    		ajaxRequest.send(null);
		    	} catch (err) {
			    	// do nothing
		    	}
	    	}
       </c:if>
    }    
    function vlcRemove(vlcIndex) {
		if ( vlcIndex == vlcSsiCurrID ) {
				vlcGet("?control=stop");
		}
		vlcGet("?control=delete&item=", vlcIndex);		 	
    }    
    function vlcAddItem(url, title) {
    	var req_url = "?control=add&mrl=" + encodeURIComponent( addslashes(escapebackslashes(url + "&suffix=.mp3"))) + "&name=" + encodeURIComponent(title);
        vlcGet(req_url);
    }    
    // This function sets variables for the Subsonic integration : SSI
    // TODO : check if server avail
	function vlcGetSsiVariables(){
    	// Replace the src of script setting vars 
	    var oldScript = document.getElementById('ssi');
	    var script = document.createElement("script");        
	    script.setAttribute("type","text/javascript");                
	    script.setAttribute("id","ssi");
	    var timestamp =  new Date;
	    script.setAttribute("src",vlc_url + "ssi.html?" + timestamp.getTime());
	
	    if (oldScript == null) {               
	        document.body.appendChild(script);
	    } else {
	        document.body.replaceChild(script, oldScript);
	    }
	}
    function vlcProcessSsiVariables() {
        // compare volume, with a 0.5% tolerance
        if ( (vlcSsiVolume < (vlcKnownVolume - 5)) || (vlcSsiVolume > (vlcKnownVolume + 5)) ) {
        	vlcKnownVolume = vlcSsiVolume;
        	newGain = vlcSsiVolume / vlcGainFactor;
            if ( newGain > 1 ) {
                newGain = 1;
            }
        	// Move slider
        	if (slider) {
            	slider.setValue(newGain * 100);
        	}
        	playlistService.setGain(newGain);
        }
        // State
        if ( vlcSsiState == "paused" || vlcSsiState == "stop" ) {
			if ( vlcKnownState == "playing" ) {
	            playlistService.stop(playlistCallback);
	            if ( vlcSsiState == "stop" ) { 
		            document.getElementById("vlcPosition").innerHTML = "0:00";
	            }
			}           
        } else if (vlcSsiState == "playing") {
        	if ( vlcKnownState != "playing" ) {
	        	// the playing case is not handled by the now plaing callback
				// reflect the change in the player control
	            $("start").hide();
	            $("stop").show();
        	}
        }
        vlcKnownState = vlcSsiState;
        
       	// Version & state      
       	if ( vlcSsiVersion != "" ) {
			if (vlcSsiVersion.indexOf("0.9.") == 0 || vlcSsiVersion.indexOf("1.") == 0) {
				vlcTranslateUrl = true;
				vlcMoveEnabled = false;
			}
	    }
       	// Position
       	if (vlcSsiPos > 0 && vlcSsiState == "playing" ) {
       		document.getElementById("vlcPosition").innerHTML = getDurationAsString(vlcSsiPos);
        }
    }
    function vlcStartPlaylistTimer() {
		// Periodically check status of VLC player 
    	vlcGetSsiVariables();
    	vlcProcessSsiVariables();    	
        setTimeout("vlcStartPlaylistTimer()", 1800);
    }
    function onSeek(seconds) {
        newPos = vlcSsiPos + seconds;
    	vlcGet("?control=seek&seek_value=" + newPos + "sec");
    }
    function onReloadVlcPlaylist(){
		// Resynchronizes the list
        vlcAction="onReload";
        playlistService.stop(playlistCallback);        
    }
    function onVolumeUp(){
         // 10% volume
		var vlcNewGain = (vlcSsiVolume / vlcGainFactor)*1.1;
		onGain(vlcNewGain);
    	// Move slider
    	if (slider) {
        	slider.setValue(vlcNewGain * 100);
    	}
    }
    function onVolumeDown(){
    	// 10% volume
		var vlcNewGain = (vlcSsiVolume / vlcGainFactor)*0.9;
		onGain(vlcNewGain);	       
    	// Move slider
    	if (slider) {
        	slider.setValue(vlcNewGain * 100);
    	} 
    }
    
    function vlcPostCallBack(index) {
    	var delta=100; // wait 100 ms betwenn adds
        // check action		    
        if ( vlcAction == "onAdd" ) {          	        
		    for (i=index; i<songs.length; i++) {
	        	setTimeout(vlcAddItem, i*delta, songs[i].streamUrl, songs[i].title);	    
	        }
        } else if ( vlcAction == "onPlay" ) {
        	vlcGet("?control=stop");
        	vlcGet("?control=empty");
	        for (i=0; i<songs.length; i++) {
	        	setTimeout(vlcAddItem, i*delta, songs[i].streamUrl, songs[i].title);
	        }
	        setTimeout(vlcGet, songs.length*delta, "?control=play");
        } else if ( vlcAction == "onReload" ) {
        	vlcGet("?control=stop");
        	vlcGet("?control=empty");          	        
		    for (i=0; i<songs.length; i++) {
	        	setTimeout(vlcAddItem, i*delta, songs[i].streamUrl, songs[i].title);	    
	        }
        }                       
        vlcAction = ""; // Reset action
    }
    function getDurationAsString(duration) {
        if (duration == 0) {
            return "0";
        }

        var result = "";

        var seconds = duration;

        var hours = Math.floor(seconds / 3600);
        seconds -= hours * 3600;

        var minutes = Math.floor(seconds / 60);
        seconds -= minutes * 60;

        if (hours > 0) {
            result += hours + ':';
            if (minutes < 10) {
            	result += '0';
            }
        }

        result += minutes + ':';
        if (seconds < 10) {
        	result += '0';
        }
        result += seconds;

        return result;
    }
	///////////////////////////////////////////////////////////////////
    	
    function init() {
        dwr.engine.setErrorHandler(null);
        startTimer();
        
        // jcduss : VLC remote player : continue only if vlc techno
		<c:if test="${model.player.VLC}">
	        vlcStartPlaylistTimer();
	    </c:if>

    <c:choose>
    <c:when test="${model.player.web}">
        createPlayer();
    </c:when>
    <c:otherwise>
        getPlaylist();
    </c:otherwise>
    </c:choose>
    }

    function startTimer() {
        // Periodically check if the current song has changed. 
        nowPlayingService.getNowPlayingForCurrentPlayer(nowPlayingCallback);
        setTimeout("startTimer()", 10000);
    }

    function nowPlayingCallback(nowPlayingInfo) {
        if (nowPlayingInfo != null && nowPlayingInfo.streamUrl != currentStreamUrl) {
            getPlaylist();
            if (currentAlbumUrl != nowPlayingInfo.albumUrl && top.main.updateNowPlaying) {
                top.main.location.replace("nowPlaying.view?");
                currentAlbumUrl = nowPlayingInfo.albumUrl;
            }
        <c:if test="${not model.player.web}">
            currentStreamUrl = nowPlayingInfo.streamUrl;
            updateCurrentImage();
        </c:if>
        }
    }

    function createPlayer() {
        var flashvars;
            flashvars = {
	            backcolor:"<spring:theme code="backgroundColor"/>",
	            frontcolor:"<spring:theme code="textColor"/>",
				id:"player1"
	        };
        
        var params = {
            allowfullscreen:"true",
            allowscriptaccess:"always"
        };
        var attributes = {
            id:"player1",
            name:"player1"
        };
        swfobject.embedSWF("<c:url value="/flash/jw-player-5.6.swf"/>", "placeholder", "340", "24", "9.0.0", false, flashvars, params, attributes);
    }

    function playerReady(thePlayer) {
        player = $("player1");
        player.addModelListener("STATE", "stateListener");
        getPlaylist();
    }

    function stateListener(obj) { // IDLE, BUFFERING, PLAYING, PAUSED, COMPLETED
        if (obj.newstate == "COMPLETED") {
            onNext(repeatEnabled);
        }
    }

    function getPlaylist() {
        playlistService.getPlaylist(playlistCallback);
    }

    function onClear() {
        var ok = true;
    <c:if test="${model.partyMode}">
        ok = confirm("<fmt:message key="playlist.confirmclear"/>");
    </c:if>
        if (ok) {
            playlistService.clear(playlistCallback);
            
	        // jcduss : VLC remote player clears VLC PL
            vlcGet("?control=empty");
            
        }
    }
    function onStart() {
        playlistService.start(playlistCallback);

        // jcduss : VLC remote player : optional test       
        <c:if test="${model.player.VLC}">
	        vlcGet("?control=play");	        
    	</c:if>
     }
    function onStop() {
        playlistService.stop(playlistCallback);
        
        // jcduss : VLC remote player        
        vlcGet("?control=pause");
    }
    function onGain(gain) {
        playlistService.setGain(gain);
        
        // jcduss : VLC remote player
        vlcKnownVolume = gain*vlcGainFactor ;
        vlcSsiVolume = vlcKnownVolume;
        vlcGet("?control=volume&value=", vlcKnownVolume);

    }
    function onSkip(index) {
    <c:choose>
    <c:when test="${model.player.web}">
        skip(index);
    </c:when>
    <c:otherwise>
        currentStreamUrl = songs[index].streamUrl;
        playlistService.skip(index, playlistCallback);
        // jcduss : VLC remote player        
        vlcGet("?control=play&item=" + vlcSsiID[index]);        
    </c:otherwise>
    </c:choose>
    }
    function onNext(wrap) {        
        // jcduss : VLC remote player : added test VLC; next/previous only supported for web and VLC player
    	<c:choose>
		    <c:when test="${model.player.VLC}">
		        vlcGet("?control=next");
		    </c:when>
		    <c:otherwise>
		        var index = parseInt(getCurrentSongIndex()) + 1;
		        if (wrap) {
		            index = index % songs.length;
		        }
		        skip(index);
		    </c:otherwise>
		</c:choose>    
    }
    function onPrevious() {
        // jcduss : VLC remote player : added test VLC; next/previous only supported for web player
    	<c:choose>
		    <c:when test="${model.player.VLC}">
		        vlcGet("?control=previous");
		    </c:when>
		    <c:otherwise>
		        skip(parseInt(getCurrentSongIndex()) - 1);
		    </c:otherwise>
		</c:choose>        
    }
    function onPlay(path) {
		// jcduss : VLC remote player : pl changed -> this loads the previously current songs (cause callback is be called after)
    	vlcAction = "onPlay";

		startPlayer = true;
        playlistService.play(path, playlistCallback);
    }
    function onPlayRandom(path, count) {
		// jcduss : VLC remote player : pl changed -> this loads the previously current songs
    	vlcAction = "onPlay";

		startPlayer = true;
        playlistService.playRandom(path, count, playlistCallback);
    }
    function onAdd(path) {
		// jcduss : VLC remote player
    	vlcAction = "onAdd";
    	
        startPlayer = false;
        playlistService.add(path, playlistCallback);

    }
    function onShuffle() {
    	<c:choose>
	    <c:when test="${model.player.VLC}"> // vlc : unsupported
	    </c:when>
	    <c:otherwise>   
	        playlistService.shuffle(playlistCallback);
	    </c:otherwise>
		</c:choose>   
    }
    function onRemove(index) {
    	<c:choose>
	    <c:when test="${model.player.VLC}">
	    	if ( vlcSsiID[index] == vlcSsiCurrID && vlcTranslateUrl) {
				// deleting the track being played is not supported by newer VLC			
			} else {
				playlistService.remove(index, playlistCallback);
				// jcduss : VLC remote player
				vlcRemove(vlcSsiID[index]);
			}
	    </c:when>
	    <c:otherwise>   
			playlistService.remove(index, playlistCallback);
	    </c:otherwise>
		</c:choose> 
    }
    function onRemoveSelected() {
        // jcduss : VLC remote player
        var vlcCurrID = vlcSsiID;
        
        var indexes = new Array();
        var counter = 0;
        for (var i = 0; i < songs.length; i++) {
            var index = i + 1;
            if ($("songIndex" + index).checked) {
            	<c:choose>
        	    <c:when test="${model.player.VLC}"> // jcduss : VLC remote player deleting the track being played is not supported by newer VLC
        	    	if (vlcSsiID[i] != vlcSsiCurrID || !vlcTranslateUrl) {
		                indexes[counter++] = i;
        	    	}
        	    </c:when>
        	    <c:otherwise>   
	                indexes[counter++] = i;
        		</c:otherwise>
        		</c:choose> 
            }
        }
        playlistService.removeMany(indexes, playlistCallback);

		// jcduss : VLC remote player : reverse order when VLC reassigns the IDs after a delete
		for (var i = indexes.length-1; i>=0; i--) {
			var vlcIndex=vlcCurrID[indexes[i]];
			vlcRemove(vlcIndex);
		}	
    }

    function onUp(index) {
    	<c:choose>
	    <c:when test="${model.player.VLC}">
        if (vlcMoveEnabled) {
	        playlistService.up(index, playlistCallback);	        				
			if (index > 0) {
				vlcGet("?control=move&psz_pos=" + vlcSsiID[index] + "&psz_newpos=" + vlcSsiID[index-1]);
			}
        }
	    </c:when>
	    <c:otherwise>
	        playlistService.up(index, playlistCallback);
	    </c:otherwise>
		</c:choose>    
    }
    function onDown(index) {
    	<c:choose>
	    <c:when test="${model.player.VLC}">
        if (vlcMoveEnabled) {
	        playlistService.down(index, playlistCallback);
	        if (index < (vlcSsiID.length-1) ) {
				vlcGet("?control=move&psz_pos=" + vlcSsiID[index] + "&psz_newpos=" + vlcSsiID[index+1]);
			}
        }
	    </c:when>
	    <c:otherwise>
	        playlistService.down(index, playlistCallback);
	    </c:otherwise>
		</c:choose>
    }
    function onToggleRepeat() {
		<c:choose>
	    <c:when test="${model.player.VLC}">
		    if ( vlcTranslateUrl ) { // jcduss : VLC remote player
				playlistService.toggleRepeat(playlistCallback);
		        // jcduss : VLC remote player : new versions only
		        vlcGet("requests/status.xml?command=pl_loop");
	        }
	    </c:when>
	    <c:otherwise>   
			playlistService.toggleRepeat(playlistCallback);
		</c:otherwise>
		</c:choose>            
	}
    function onUndo() {
        playlistService.undo(playlistCallback);
    }
    function onSortByTrack() {
    	<c:choose>
	    <c:when test="${model.player.VLC}"> // vlc : unsupported
	    </c:when>
	    <c:otherwise>   
	        playlistService.sortByTrack(playlistCallback);
	    </c:otherwise>
		</c:choose>   
    }
    function onSortByArtist() {
    	<c:choose>
	    <c:when test="${model.player.VLC}"> // vlc : unsupported
	    </c:when>
	    <c:otherwise>   
	        playlistService.sortByArtist(playlistCallback);
	    </c:otherwise>
		</c:choose>   
    }
    function onSortByAlbum() {
    	<c:choose>
	    <c:when test="${model.player.VLC}">	// vlc : unsupported
	    </c:when>
	    <c:otherwise>   
	        playlistService.sortByAlbum(playlistCallback);
	    </c:otherwise>
		</c:choose>   
    }

    function playlistCallback(playlist) {
        // jcduss : VLC remote player : store size of PL before adding
        var initialCount = vlcSongsCount;
        songs = playlist.entries;

        // jcduss : VLC remote player : update size of PL
        vlcSongsCount = songs.length;
        //alert('playlistCallback; action ' + vlcAction + ' initialCount ' + initialCount + ' vlcSongsCount ' + vlcSongsCount);
        //alert('playlist.name ' + playlist.name);
        repeatEnabled = playlist.repeatEnabled;
        if ($("start")) {
            if (playlist.stopEnabled) {
                $("start").hide();
                $("stop").show();
            } else {
                $("start").show();
                $("stop").hide();
            }
        }

        if ($("toggleRepeat")) {
            var text = repeatEnabled ? "<fmt:message key="playlist.repeat_on"/>" : "<fmt:message key="playlist.repeat_off"/>";
            dwr.util.setValue("toggleRepeat", text);
        }

        if (songs.length == 0) {
            $("empty").show();
        } else {
            $("empty").hide();
        }

        // Delete all the rows except for the "pattern" row
        dwr.util.removeAllRows("playlistBody", { filter:function(tr) {
            return (tr.id != "pattern");
        }});

        // jcduss : VLC remote player : totalDuration 
	    <c:if test="${model.player.VLC}">
	        var totalDuration = 0;
	    </c:if>

        // Create a new set cloned from the pattern row
        for (var i = 0; i < songs.length; i++) {
            var song  = songs[i];
            var id = i + 1;
            dwr.util.cloneNode("pattern", { idSuffix:id });
            if ($("trackNumber" + id)) {
                dwr.util.setValue("trackNumber" + id, song.trackNumber);
            }

            if ($("currentImage" + id) && song.streamUrl == currentStreamUrl) {
                $("currentImage" + id).show();
            }
            if ($("title" + id)) {
                dwr.util.setValue("title" + id, truncate(song.title));
                $("title" + id).title = song.title;
            }
            if ($("titleUrl" + id)) {
                dwr.util.setValue("titleUrl" + id, truncate(song.title));
                $("titleUrl" + id).title = song.title;
                $("titleUrl" + id).onclick = function () {onSkip(this.id.substring(8) - 1)};
            }
            if ($("album" + id)) {
                dwr.util.setValue("album" + id, truncate(song.album));
                $("album" + id).title = song.album;
                $("albumUrl" + id).href = song.albumUrl;
            }
            if ($("artist" + id)) {
                dwr.util.setValue("artist" + id, truncate(song.artist));
                $("artist" + id).title = song.artist;
            }
            if ($("genre" + id)) {
                dwr.util.setValue("genre" + id, song.genre);
            }
            if ($("year" + id)) {
                dwr.util.setValue("year" + id, song.year);
            }
            if ($("bitRate" + id)) {
                dwr.util.setValue("bitRate" + id, song.bitRate);
            }
            if ($("duration" + id)) {
                dwr.util.setValue("duration" + id, song.durationAsString);
            }
            if ($("format" + id)) {
                dwr.util.setValue("format" + id, song.format);
            }
            if ($("fileSize" + id)) {
                dwr.util.setValue("fileSize" + id, song.fileSize);
            }
            // jcduss : VLC remote player : add playlist index
    	    <c:if test="${model.player.VLC}">
 	            if ($("playlistNumber" + id)) {
        	        dwr.util.setValue("playlistNumber" + id, id);
    	        }
    	    </c:if>
            // jcduss : VLC remote player : add totalDuration index
    	    <c:if test="${model.player.VLC}">
 	            if ($("totalDuration" + id)) {
        	        totalDuration = totalDuration + song.duration;
        	        dwr.util.setValue("totalDuration" + id, getDurationAsString(totalDuration));
    	        }
    	    </c:if>
    	    
            $("pattern" + id).show();
            $("pattern" + id).className = (i % 2 == 0) ? "bgcolor1" : "bgcolor2";
        }

        if (playlist.sendM3U) {
            parent.frames.main.location.href="play.m3u?";
        }

        if (slider) {
            slider.setValue(playlist.gain * 100);
        }

        <c:if test="${model.player.web}">
            triggerPlayer();
        </c:if>
        
        // jcduss : VLC remote player
	    <c:if test="${model.player.VLC}">
			// Check if called form saved playlist load and random page
			// TODO : reset operation locally
	        if ( playlist.vlcPlaylistOperation == "loadPlaylistConfirm" ||
	        		playlist.vlcPlaylistOperation == "loadPlaylistRandom" ) {
				vlcAction = "onPlay";
				playlistService.vlcResetPlaylistOperation();
		    }
	       vlcPostCallBack(initialCount);
	    </c:if>
    }

    function triggerPlayer() {
        if (startPlayer) {
            startPlayer = false;
            if (songs.length > 0) {
                skip(0);
            }
        }
        updateCurrentImage();
        if (songs.length == 0) {
            player.sendEvent("LOAD", new Array());
            player.sendEvent("STOP");
        }
    }

    function skip(index) {
        if (index < 0 || index >= songs.length) {
            return;
        }

        var song = songs[index];
        currentStreamUrl = song.streamUrl;
        updateCurrentImage();
        var list = new Array();
        list[0] = {
            file:song.streamUrl,
            title:song.title,
            provider:"sound"
        };

        if (song.duration != null) {
            list[0].duration = song.duration;
        }
        if (song.format == "aac" || song.format == "m4a") {
            list[0].provider = "video";
        }

        player.sendEvent("LOAD", list);
        player.sendEvent("PLAY");
    }

    function updateCurrentImage() {
        for (var i = 0; i < songs.length; i++) {
            var song  = songs[i];
            var id = i + 1;
            var image = $("currentImage" + id);

            if (image) {
                if (song.streamUrl == currentStreamUrl) {
                    image.show();
                } else {
                    image.hide();
                }
            }
        }
    }

    function getCurrentSongIndex() {
        for (var i = 0; i < songs.length; i++) {
            if (songs[i].streamUrl == currentStreamUrl) {
                return i;
            }
        }
        return -1;
    }

    function truncate(s) {
        var cutoff = ${model.visibility.captionCutoff};

        if (s.length > cutoff) {
            return s.substring(0, cutoff) + "...";
        }
        return s;
    }

//     actionSelected() is invoked when the users selects from the "More actions..." combo box. 
    function actionSelected(id) {
        if (id == "top") {
            return;
        } else if (id == "loadPlaylist") {
            parent.frames.main.location.href = "loadPlaylist.view?";
        } else if (id == "savePlaylist") {
            parent.frames.main.location.href = "savePlaylist.view?";
        } else if (id == "downloadPlaylist") {
            location.href = "download.view?player=${model.player.id}";
        } else if (id == "sharePlaylist") {
            parent.frames.main.location.href = "createShare.view?player=${model.player.id}&" + getSelectedIndexes();
        } else if (id == "sortByTrack") {
            onSortByTrack();
        } else if (id == "sortByArtist") {
            onSortByArtist();
        } else if (id == "sortByAlbum") {
            onSortByAlbum();
        } else if (id == "selectAll") {
            selectAll(true);
        } else if (id == "selectNone") {
            selectAll(false);
        } else if (id == "removeSelected") {
            onRemoveSelected();
        } else if (id == "download") {
            location.href = "download.view?player=${model.player.id}&" + getSelectedIndexes();
        } else if (id == "appendPlaylist") {
            parent.frames.main.location.href = "appendPlaylist.view?player=${model.player.id}&" + getSelectedIndexes();
        }
        $("moreActions").selectedIndex = 0;
    }

    function getSelectedIndexes() {
        var result = "";
        for (var i = 0; i < songs.length; i++) {
            if ($("songIndex" + (i + 1)).checked) {
                result += "i=" + i + "&";
            }
        }
        return result;
    }

    function selectAll(b) {
        for (var i = 0; i < songs.length; i++) {
            $("songIndex" + (i + 1)).checked = b;
        }
    }

--></script>

<div class="bgcolor2" style="position:fixed; top:0; width:100%;padding-top:0.5em">
    <table style="white-space:nowrap;">
        <tr style="white-space:nowrap;">
            <c:if test="${model.user.settingsRole}">
                <td><select name="player" onchange="location='playlist.view?player=' + options[selectedIndex].value;">
                    <c:forEach items="${model.players}" var="player">
                        <option ${player.id eq model.player.id ? "selected" : ""} value="${player.id}">${player.shortDescription}</option>
                    </c:forEach>
                </select></td>
            </c:if>
            <c:if test="${model.player.web}">
                <td style="width:340px; height:24px;padding-left:10px;padding-right:10px"><div id="placeholder">
                    <a href="http://www.adobe.com/go/getflashplayer" target="_blank"><fmt:message key="playlist.getflash"/></a>
                </div></td>
            </c:if>

            <c:if test="${model.user.streamRole and not model.player.web}">
                <td style="white-space:nowrap;" id="stop"><b><a href="javascript:noop()" onclick="onStop()"><fmt:message key="playlist.stop"/></a></b> | </td>
                <td style="white-space:nowrap;" id="start"><b><a href="javascript:noop()" onclick="onStart()"><fmt:message key="playlist.start"/></a></b> | </td>
            </c:if>

            <c:if test="${model.player.jukebox}">
                <td style="white-space:nowrap;">
                    <img src="<spring:theme code="volumeImage"/>" alt="">
                </td>
                <td style="white-space:nowrap;">
                    <div class="slider bgcolor2" id="slider-1" style="width:90px">
                        <input class="slider-input" id="slider-input-1" name="slider-input-1">
                    </div>
                    <script type="text/javascript">

                        var updateGainTimeoutId = 0;
                        slider = new Slider(document.getElementById("slider-1"), document.getElementById("slider-input-1"));
                        slider.onchange = function () {
                            clearTimeout(updateGainTimeoutId);
                            updateGainTimeoutId = setTimeout("updateGain()", 250);
                        };

                        function updateGain() {
                            var gain = slider.getValue() / 100.0;
                            onGain(gain);
                        }
                    </script>
                </td>
            </c:if>
			<!--  jcduss : VLC remote player  : added Slider for VLC -->
		<c:if test="${model.player.VLC}">			
			<td style="white-space: nowrap;"><img
				src="<spring:theme code="volumeImage"/>" alt=""></td>
			<td style="white-space: nowrap;">
			<div class="slider bgcolor2" id="slider-1" style="width: 90px">
			<input class="slider-input" id="slider-input-1" name="slider-input-1">
			</div>
			<script type="text/javascript">

                        var updateGainTimeoutId = 0;
                        slider = new Slider(document.getElementById("slider-1"), document.getElementById("slider-input-1"));
                        slider.onchange = function () {
                            clearTimeout(updateGainTimeoutId);
                            updateGainTimeoutId = setTimeout("updateGain()", 250);
                        };

                        function updateGain() {
                            var gain = slider.getValue() / 100.0;
                            onGain(gain);
                            // jcduss : VLC remote player
                            document.getElementById("slider-1");
                        }
                    </script></td>
            
            <!--  jcduss : VLC remote player  : added volumeUp/Down -->
            <td style="white-space: nowrap;">
            <a href="javascript:noop()" onclick="onVolumeUp()"> <b>+</b></a></td>
            <td style="white-space: nowrap;">
            <a href="javascript:noop()" onclick="onVolumeDown()"> <b>&ndash;</b></a> |</td>
            <!--  jcduss : VLC remote player  : added position -->
            <td style="white-space: nowrap;">
            <div id="vlcPosition">
            	0:00
            </div>
            </td>
            <!--  jcduss : VLC remote player  : added Seek -->
            <td style="white-space: nowrap;">
			+ <a href="javascript:noop()"
				onclick="onSeek(+60)"><b>01</b></a>
				<a href="javascript:noop()"
				onclick="onSeek(+300)"><b>05</b></a>
				<a href="javascript:noop()"
				onclick="onSeek(+600)"><b>10</b></a>
				<a href="javascript:noop()"
				onclick="onSeek(+1800)"><b>30</b></a>
			- <a href="javascript:noop()"
				onclick="onSeek(-60)"><b>01</b></a>
				<a href="javascript:noop()"
				onclick="onSeek(-300)"><b>05</b></a>
				<a href="javascript:noop()"
				onclick="onSeek(-600)"><b>10</b></a>
				 min |
			</td>
		</c:if>
		<!-- jcduss : VLC remote player : added VLC -->
		
            <c:if test="${model.player.web or model.player.VLC}">
                <td style="white-space:nowrap;"><a href="javascript:noop()" onclick="onPrevious()"><b>&laquo;</b></a></td>
                <td style="white-space:nowrap;"><a href="javascript:noop()" onclick="onNext(false)"><b>&raquo;</b></a> |</td>
            </c:if>

            <td style="white-space:nowrap;"><a href="javascript:noop()" onclick="onClear()"><fmt:message key="playlist.clear"/></a> |</td>
		<!-- jcduss : VLC remote player : excluded VLC -->
		<c:if test="${not model.player.VLC}">
            <td style="white-space:nowrap;"><a href="javascript:noop()" onclick="onShuffle()"><fmt:message key="playlist.shuffle"/></a> |</td>
		</c:if>
		<!-- jcduss : VLC remote player : added VLC -->
		<c:if
			test="${model.player.web or model.player.jukebox or model.player.external or model.player.VLC}">
			<td style="white-space:nowrap;"><a href="javascript:noop()" onclick="onToggleRepeat()"><span id="toggleRepeat"><fmt:message key="playlist.repeat_on"/></span></a> |</td>
        </c:if>

		<!-- jcduss : VLC remote player : excluded VLC -->
		<c:if test="${not model.player.VLC}">
			<td style="white-space: nowrap;"><a href="javascript:noop()"
				onclick="onUndo()"><fmt:message key="playlist.undo" /></a> |</td>
		</c:if>
		<!--  jcduss : VLC remote player  : added reload for VLC -->
		<c:if test="${model.player.VLC}">
			<td style="white-space: nowrap;"><a href="javascript:noop()"
				onclick="onReloadVlcPlaylist()">Synchronize</a> |</td>	
		</c:if>
		
            <c:if test="${model.user.settingsRole}">
                <td style="white-space:nowrap;"><a href="playerSettings.view?id=${model.player.id}" target="main"><fmt:message key="playlist.settings"/></a> |</td>
            </c:if>

            <td style="white-space:nowrap;"><select id="moreActions" onchange="actionSelected(this.options[selectedIndex].id)">
                <option id="top" selected="selected"><fmt:message key="playlist.more"/></option>
                <option style="color:blue;"><fmt:message key="playlist.more.playlist"/></option>
                <option id="loadPlaylist">&nbsp;&nbsp;&nbsp;&nbsp;<fmt:message key="playlist.load"/></option>
                <c:if test="${model.user.playlistRole}">
                    <option id="savePlaylist">&nbsp;&nbsp;&nbsp;&nbsp;<fmt:message key="playlist.save"/></option>
                </c:if>
                <c:if test="${model.user.downloadRole}">
                    <option id="downloadPlaylist">&nbsp;&nbsp;&nbsp;&nbsp;<fmt:message key="common.download"/></option>
                </c:if>
                <c:if test="${model.user.shareRole}">
                    <option id="sharePlaylist">&nbsp;&nbsp;&nbsp;&nbsp;<fmt:message key="main.more.share"/></option>
                </c:if>
                <option id="sortByTrack">&nbsp;&nbsp;&nbsp;&nbsp;<fmt:message key="playlist.more.sortbytrack"/></option>
                <option id="sortByAlbum">&nbsp;&nbsp;&nbsp;&nbsp;<fmt:message key="playlist.more.sortbyalbum"/></option>
                <option id="sortByArtist">&nbsp;&nbsp;&nbsp;&nbsp;<fmt:message key="playlist.more.sortbyartist"/></option>
                <option style="color:blue;"><fmt:message key="playlist.more.selection"/></option>
                <option id="selectAll">&nbsp;&nbsp;&nbsp;&nbsp;<fmt:message key="playlist.more.selectall"/></option>
                <option id="selectNone">&nbsp;&nbsp;&nbsp;&nbsp;<fmt:message key="playlist.more.selectnone"/></option>
                <option id="removeSelected">&nbsp;&nbsp;&nbsp;&nbsp;<fmt:message key="playlist.remove"/></option>
                <c:if test="${model.user.downloadRole}">
                    <option id="download">&nbsp;&nbsp;&nbsp;&nbsp;<fmt:message key="common.download"/></option>
                </c:if>
                <c:if test="${model.user.playlistRole}">
                    <option id="appendPlaylist">&nbsp;&nbsp;&nbsp;&nbsp;<fmt:message key="playlist.append"/></option>
                </c:if>
            </select>
            </td>

        </tr></table>
</div>

<div style="height:3.2em"></div>

<p id="empty"><em><fmt:message key="playlist.empty"/></em></p>

<table style="border-collapse:collapse;white-space:nowrap;">
    <tbody id="playlistBody">
        <tr id="pattern" style="display:none;margin:0;padding:0;border:0">
            <td class="bgcolor2"><a href="javascript:noop()">
                <img id="removeSong" onclick="onRemove(this.id.substring(10) - 1)" src="<spring:theme code="removeImage"/>"
                     alt="<fmt:message key="playlist.remove"/>" title="<fmt:message key="playlist.remove"/>"></a></td>
            <td class="bgcolor2"><a href="javascript:noop()">
                <img id="up" onclick="onUp(this.id.substring(2) - 1)" src="<spring:theme code="upImage"/>"
                     alt="<fmt:message key="playlist.up"/>" title="<fmt:message key="playlist.up"/>"></a></td>
            <td class="bgcolor2"><a href="javascript:noop()">
                <img id="down" onclick="onDown(this.id.substring(4) - 1)" src="<spring:theme code="downImage"/>"
                     alt="<fmt:message key="playlist.down"/>" title="<fmt:message key="playlist.down"/>"></a></td>

            <td class="bgcolor2" style="padding-left: 0.1em"><input type="checkbox" class="checkbox" id="songIndex"></td>
            <td style="padding-right:0.25em"></td>

			<c:if test="${model.visibility.trackNumberVisible}">
				<td style="padding-right: 0.5em; text-align: right"><span
					class="detail" id="trackNumber">1</span></td>
			</c:if>
			<!-- jcduss : VLC remote player : playlistNumber -->
			<c:if test="${model.player.VLC}">
				<td style="padding-right: 0.5em; text-align: right"><span
					class="detail" id="playlistNumber">1</span></td>
			</c:if>

            <td style="padding-right:1.25em">
                <img id="currentImage" src="<spring:theme code="currentImage"/>" alt="" style="display:none">
                <c:choose>
                    <c:when test="${model.player.externalWithPlaylist}">
                        <span id="title">Title</span>
                    </c:when>
                    <c:otherwise>
                        <a id="titleUrl" href="javascript:noop()">Title</a>
                    </c:otherwise>
                </c:choose>
            </td>

            <c:if test="${model.visibility.albumVisible}">
                <td style="padding-right:1.25em"><a id="albumUrl" target="main"><span id="album" class="detail">Album</span></a></td>
            </c:if>
            <c:if test="${model.visibility.artistVisible}">
                <td style="padding-right:1.25em"><span id="artist" class="detail">Artist</span></td>
            </c:if>
            <c:if test="${model.visibility.genreVisible}">
                <td style="padding-right:1.25em"><span id="genre" class="detail">Genre</span></td>
            </c:if>
            <c:if test="${model.visibility.yearVisible}">
                <td style="padding-right:1.25em"><span id="year" class="detail">Year</span></td>
            </c:if>
            <c:if test="${model.visibility.formatVisible}">
                <td style="padding-right:1.25em"><span id="format" class="detail">Format</span></td>
            </c:if>
            <c:if test="${model.visibility.fileSizeVisible}">
                <td style="padding-right:1.25em;text-align:right;"><span id="fileSize" class="detail">Format</span></td>
            </c:if>
            <c:if test="${model.visibility.durationVisible}">
                <td style="padding-right:1.25em;text-align:right;"><span id="duration" class="detail">Duration</span></td>
				<!-- jcduss : VLC remote player : totalDuration -->
				<c:if test="${model.player.VLC}">
					<td style="padding-right: 0.5em; text-align: right"><span
						class="detail" id="totalDuration">Total</span></td>
				</c:if>            
            </c:if>
            <c:if test="${model.visibility.bitRateVisible}">
                <td style="padding-right:0.25em"><span id="bitRate" class="detail">Bit Rate</span></td>
            </c:if>
        </tr>
    </tbody>
</table>

</body></html>
// temporary: ignore the entire contents of this file when building for web
CONFIG::desktop {
package {
	import flash.display.*;
	import flash.geom.*;
  import flash.events.*;
	import flash.utils.*;
  import flash.net.*;
	import flash.filesystem.*;
	import org.si.sion.midi.*;
	import org.si.sion.events.*;
	
	import com.newgonzo.midi.MIDIDecoder;
	import com.newgonzo.midi.messages.*;
	import com.newgonzo.midi.file.*;
	
	public class midicontrol {
		public static function resetinstruments():void {
			if (channelinstrument.length == 0) {
				for (var i:int = 0; i < 16; i++) {
					channelinstrument.push(-1);
				}
			}else {
				for (i = 0; i < 16; i++) {
					channelinstrument[i] = -1;
				}
			}
		}
		
    public static var smfData:SMFData = new SMFData();
		public static function openfile():void {
			control.stopmusic();	
			
			file = File.desktopDirectory.resolvePath("");
		  file.addEventListener(Event.SELECT, onloadmidi);
			file.browseForOpen("Load .mid File", [midiFilter]);
		}
		
		private static function onloadmidi(e:Event):void {  
			midiData = new ByteArray();
			file = e.currentTarget as File;
			
			stream = new FileStream();
			stream.open(file, FileMode.READ);
			stream.readBytes(midiData);
			stream.close();
			
			decoder = new MIDIDecoder();
      midifile = decoder.decodeFile(midiData);
			
			smfData.loadBytes(midiData);
			
			var track:MIDITrack;
			var event:MIDITrackEvent;
			
			trace("midifile.division = " + String(midifile.division));
			trace("midifile.format = " + String(midifile.format));
			trace("midifile.numTracks = " + String(midifile.numTracks));
			
			var v:VoiceMessage;
			var c:ChannelMessage; 
			var d:DataMessage; 
			
			clearnotes();
			resetinstruments();
			
			for each(track in midifile.tracks) {
				for each(event in track.events){
					if (event.message.status == MessageStatus.NOTE_ON) {
						v = event.message as VoiceMessage;
						//trace(event.message.toString());
						addnote(event.time, v.pitch, v.channel);
						//trace(event.time, event.message.toString() + ", pitch = " + String(v.pitch));
					}else if (event.message.status == MessageStatus.NOTE_OFF) {
						v = event.message as VoiceMessage;
						//trace(event.time, event.message.toString() + ", pitch = " + String(v.pitch));
					}else if (event.message.status == MessageStatus.PROGRAM_CHANGE) {
						d = event.message as DataMessage;
						c = event.message as ChannelMessage;
						channelinstrument[c.channel] = d.data1;
					}
				}
			} 
			
			convertmiditoceol();
			
			control.showmessage("MIDI IMPORTED");
			control.fixmouseclicks = true;
		}
		
		public static function clearnotes():void {
			midinotes = new Vector.<Rectangle>;
		}
		
		public static function addnote(time:int, note:int, instr:int):void {
			midinotes.push(new Rectangle(time, note, 1, instr));
			//trace("adding note: ", time, note, instr);
		}
		
		private static function siononloadmidi(e:Event):void {  
			midiData = new ByteArray();
			file = e.currentTarget as File;
			
			stream = new FileStream();
			stream.open(file, FileMode.READ);
			stream.readBytes(midiData);
			stream.close();
			
			smfData.loadBytes(midiData);
			
			trace(smfData.toString());
			
			var track:SMFTrack;
			var event:SMFEvent;
			/*
			clearnotes();
			
			for each(track in smfData.tracks) {
				for each(event in track.sequence) {
					if (event.type == SMFEvent.NOTE_ON) {
					  trace("NOTE ON", event.note, event.channel, event.type, event.time);
						addnote(event.time, event.note, event.type);
					}else if (event.type == SMFEvent.NOTE_OFF) {
					  trace("NOTE OFF", event.note, event.channel, event.type, event.time);
					}
				}
			} 
			
			convertmiditoceol();
			*/
			control._driver.setBeatCallbackInterval(1);
			control._driver.setTimerInterruption(1, null);
      control._driver.play(smfData, false);
			
      //control._driver.addEventListener(SiONMIDIEvent.NOTE_ON, onNoteOn);
			
			
			/*
			decoder = new MIDIDecoder();
			
      midifile = decoder.decodeFile(midiData);
			
			// a MIDI file has an array of tracks that each contain an array of track events
			var track:MIDITrack;
			var event:MIDITrackEvent;
			
			for each(track in midifile.tracks){
				for each(event in track.events){
					trace("event.time: " + event.time);
					trace("event.message: " + event.message); // [Message(status=...]
				}
			} */
			/*
			loadfilestring(filestring);
			_driver.play(null, false);
			
			*/
			control.showmessage("MIDI IMPORTED");
			control.fixmouseclicks = true;
		}
		
		public static var resolution:Number;
		public static var signature:Number;
		public static var numnotes:int;
		public static var numpatterns:int;
		
		public static function getsonglength():int {
			return int(smfData.measures);
		}
		
		public static function reversechannelinstrument(t:int):int {
			//Given instrument number t, return first channel using it.
			for (var i:int = 0; i < 16; i++) {
				if (channelinstrument[i] == t) return i;
			}
			return -1;
		}
		
		public static function gettopbox(currentpattern:int, chan:int):int {
			//return the first musicbox to either match instrument or be empty
			for (var i:int = 0; i < 16; i++) {
				if(control.arrange.bar[currentpattern].channel[i] == -1) {
					return i;
				}else {
					if (channelinstrument[chan] != -1) {
						if (reversechannelinstrument(channelinstrument[control.musicbox[control.arrange.bar[currentpattern].channel[i]].instr]) == reversechannelinstrument(channelinstrument[chan])) {
							return i;
						}	
					}					
				}
			}
			return 0;
		}
		
		public static function getmusicbox(currentpattern:int, chan:int):int {
			//Find (or create a new) music box at the position we're placing the note.
			var top:int = gettopbox(currentpattern, chan);
			
			if (control.arrange.bar[currentpattern].channel[top] == -1) {
				control.currentinstrument = chan;
				if (channelinstrument[chan] > -1) {
					control.voicelist.index = channelinstrument[chan];
					control.changeinstrumentvoice(control.voicelist.name[control.voicelist.index]);
				}else {
					control.voicelist.index = 0;
					control.changeinstrumentvoice(control.voicelist.name[control.voicelist.index]);
				}
				control.addmusicbox();
				control.arrange.addpattern(currentpattern, top, control.numboxes - 1);
				return control.numboxes - 1;
			}else {
				return control.arrange.bar[currentpattern].channel[top];
			}
			
			return -1;
		}
		
		public static function addnotetoceol(currentpattern:int, time:int, pitch:int, notelength:int, chan:int):void {
			//control.musicbox[currentpattern + (instr * numpatterns)].addnote(time, pitch, notelength);
			currentpattern = getmusicbox(currentpattern, chan);
			if(currentpattern>-1){
				control.musicbox[currentpattern].addnote(time, pitch, notelength);
			}
		}
		
		public static function convertmiditoceol():void {
			control.newsong();
			control.numboxes = 0;
			control.bpm = (smfData.bpm - (smfData.bpm % 5));
			control._driver.bpm = control.bpm;
			control._driver.play(null, false);
			
			for (var tst:int = 0; tst < 16; tst++) trace("channel " + String(tst) + " uses instrument " + String(channelinstrument[tst]));
			
			//trace(smfData.resolution);
			/*
			trace(smfData.toString());
			trace(smfData.signature_n, smfData.signature_d);
			trace(smfData.measures);
			*/
			
			resolution = smfData.resolution;
			signature = smfData.signature_d;
			numnotes = smfData.signature_d * smfData.signature_n;
			if (numnotes > 16) control.doublesize = true;
			
			var boxsize:int = resolution;
			numpatterns = getsonglength();
			control.numboxes = 0;
			control.arrange.bar[0].channel[0] = -1;
			
			control.numinstrument = 16;
			for (var j:int = 0; j < 16; j++) {
			  control.currentinstrument = j;
				if (channelinstrument[j] > -1) {
					control.voicelist.index = channelinstrument[j];
					control.changeinstrumentvoice(control.voicelist.name[control.voicelist.index]);
				}
			}
			
			for (var i:int = 0; i < midinotes.length; i++) {
				//x = time
				//y = note
				//w = length
				//h = instrument
				var t:int = ((midinotes[i].x * numnotes) / boxsize);
				var currentpattern:int = int((midinotes[i].x  - (midinotes[i].x % boxsize)) / boxsize);
				addnotetoceol(currentpattern, t - (numnotes * currentpattern), midinotes[i].y, midinotes[i].width, midinotes[i].height);
			}
			
			control.arrange.loopstart = 0;
			control.arrange.loopend = control.arrange.lastbar;	
			if (control.arrange.loopend <= control.arrange.loopstart) {
				control.arrange.loopend = control.arrange.loopstart + 1;
			}
		}
		
		CONFIG::desktop {
			public static var file:File, stream:FileStream;
		}
		
		public static var midifile:MIDIFile;
		public static var decoder:MIDIDecoder;
		public static var midiData:ByteArray;
		
		public static function onNoteOn(e:SiONMIDIEvent):void {
			trace(e.midiChannelNumber, e.note);
    }
		
		public static var midiFilter:FileFilter = new FileFilter("Midi", "*.mid");
		
		public static var midinotes:Vector.<Rectangle> = new Vector.<Rectangle>;
		public static var channelinstrument:Vector.<int> = new Vector.<int>;
	}
}

}
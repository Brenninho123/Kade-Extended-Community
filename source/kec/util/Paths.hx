package kec.util;

#if cpp
import cpp.vm.Gc;
#end
import openfl.media.Sound;
import haxe.ui.ToolkitAssets;
import flixel.graphics.FlxGraphic;
import flixel.graphics.frames.FlxFramesCollection;
import flixel.graphics.frames.FlxAtlasFrames;
import lime.utils.Assets;
import openfl.system.System;
import openfl.display3D.textures.RectangleTexture;
import openfl.utils.AssetType;
import openfl.utils.Assets as OpenFlAssets;
import openfl.display3D.textures.Texture;
import openfl.display.BitmapData;
import flixel.graphics.frames.FlxBitmapFont;
#if mobile
import lime.app.Application;
#end

class Paths
{
	public static var graphics:Map<String, FlxGraphic>;
	public static var sounds:Map<String, Sound>;

	#if mobile
	public static var maxCacheEntries:Int = 40;
	#end

	public static function initialize()
	{
		graphics = new Map<String, FlxGraphic>();
		sounds = new Map<String, Sound>();
		#if cpp
		Gc.enable(true);
		#end
		#if mobile
		Application.current.window.onFocusOut.add(onMobileFocusOut);
		#end
	}

	#if mobile
	static function onMobileFocusOut():Void
	{
		clearCache();
	}
	#end

	public static inline function getPath(file:String = '')
	{
		#if android
		return 'assets/shared/${file.toLowerCase()}';
		#else
		return 'assets/shared/$file';
		#end
	}

	public static inline function file(file:String)
		return getPath(file);

	public static inline function txt(txt:String)
		return getPath('$txt.txt');

	public static inline function json(file:String)
		return getPath('$file.json');

	public static inline function lua(file:String)
		return getPath('data/$file.lua');

	public static inline function font(key:String)
		return 'assets/fonts/$key';

	public static inline function fontXML(key:String):Xml
		return Xml.parse(OpenFlAssets.getText(getPath('images/$key.fnt')));

	public static function loadJSON(key:String):Dynamic
	{
		var rawJson:String = null;
		if (OpenFlAssets.exists(json(key), TEXT))
			rawJson = OpenFlAssets.getText(json(key)).trim();
		else
		{
			Debug.logWarn('Error Finding JSON at $key');
			return null;
		}

		while (!rawJson.endsWith("}"))
			rawJson = rawJson.substr(0, rawJson.length - 1);

		try
		{
			return Json.parse(rawJson);
		}
		catch (e)
		{
			Debug.logWarn('Error Parsing JSON $key');
			Debug.logError(e.message);
		}
		return null;
	}

	inline static public function formatToSongPath(path:String)
	{
		final invalidChars = ~/[~&;:<>#\s]/g;
		final hideChars = ~/[.,'"%?!]/g;

		return hideChars.replace(invalidChars.replace(path, '-'), '').trim().toLowerCase();
	}

	public static inline function fileExists(key:String)
	{
		if (OpenFlAssets.exists(getPath(key)))
			return true;

		return false;
	}

	public static function video(file:String)
		return 'assets/videos/$file';

	public static function image(path:String, ?useGPU:Bool):FlxGraphic
	{
		var img:String = getPath('images/$path.png');
		if (!OpenFlAssets.exists(img, IMAGE))
		{
			Debug.logWarn("Couldn't Find Asset At " + img);
			return null;
		}
		if (graphics.exists(path))
			return graphics[path];
		final graphic:FlxGraphic = FlxGraphic.fromBitmapData(OpenFlAssets.getBitmapData(img));

		#if mobile
		useGPU = useGPU != null ? useGPU : true;
		#else
		useGPU = useGPU != null ? useGPU : FlxG.save.data.gpuRender;
		#end

		if (useGPU)
			graphic.bitmap.disposeImage();

		graphic.persist = true;
		graphics[path] = graphic;

		#if mobile
		trimGraphicsCache();
		#end

		return graphics[path];
	}

	public static function getAtlas(key:String, ?useGPU:Bool):FlxAtlasFrames
	{
		final imageLoaded:FlxGraphic = image(key, useGPU);
		final myXml:Dynamic = getPath('images/$key.xml');
		final myTxt:Dynamic = getPath('images/$key.txt');
		final myJson:Dynamic = getPath('images/$key.json');
		if (OpenFlAssets.exists(myXml))
			return FlxAtlasFrames.fromSparrow(imageLoaded, myXml);
		else if (OpenFlAssets.exists(myTxt))
			return FlxAtlasFrames.fromSpriteSheetPacker(imageLoaded, myTxt);
		else if (OpenFlAssets.exists(myJson))
			return FlxAtlasFrames.fromTexturePackerJson(imageLoaded, myJson);

		return null;
	}

	public static function getMultiAtlas(keys:Array<String>, ?allowGPU:Bool):FlxAtlasFrames
	{
		var parentFrames:FlxAtlasFrames = Paths.getAtlas(keys[0].trim());
		if (keys.length > 1)
		{
			var original:FlxAtlasFrames = parentFrames;
			parentFrames = new FlxAtlasFrames(parentFrames.parent);
			parentFrames.addAtlas(original, true);
			for (i in 1...keys.length)
			{
				var extraFrames:FlxAtlasFrames = Paths.getAtlas(keys[i].trim(), allowGPU);
				if (extraFrames != null)
					parentFrames.addAtlas(extraFrames, true);
			}
		}
		return parentFrames;
	}

	static public function getSparrowAtlas(key:String, ?gpuRender:Bool)
	{
		#if mobile
		gpuRender = gpuRender != null ? gpuRender : true;
		#else
		gpuRender = gpuRender != null ? gpuRender : FlxG.save.data.gpuRender;
		#end
		return FlxAtlasFrames.fromSparrow(image(key, gpuRender), file('images/$key.xml'));
	}

	static public function getPackerAtlas(key:String, ?gpuRender:Bool)
	{
		#if mobile
		gpuRender = gpuRender != null ? gpuRender : true;
		#else
		gpuRender = gpuRender != null ? gpuRender : FlxG.save.data.gpuRender;
		#end
		return FlxAtlasFrames.fromSpriteSheetPacker(image(key, gpuRender), file('images/$key.txt'));
	}

	static public function getJSONAtlas(key:String, ?library:String, ?gpuRender:Bool)
	{
		#if mobile
		gpuRender = gpuRender != null ? gpuRender : true;
		#else
		gpuRender = gpuRender != null ? gpuRender : FlxG.save.data.gpuRender;
		#end
		return FlxAtlasFrames.fromTexturePackerJson(image(key, gpuRender), file('images/$key.json'));
	}

	static public function bitmapFont(key:String):FlxBitmapFont
	{
		return FlxBitmapFont.fromAngelCode(image(key), fontXML(key));
	}

	public static function loadSound(path:String, ?soundStreaming:Bool = false, ?returnString:Bool = false):Any
	{
		var key:String = getPath('$path.ogg');

		if (!OpenFlAssets.exists(key, SOUND))
		{
			Debug.logWarn("Couldn't Find Sound At " + key);
			path = 'error';
			key = getPath('sounds/error.ogg');
		}

		if (returnString)
			return key;

		if (sounds.exists(path))
			return sounds[path];

		var output:Sound;

		#if mobile
		soundStreaming = true;
		#end

		if (soundStreaming)
		{
			var sound:lime.media.vorbis.VorbisFile = lime.media.vorbis.VorbisFile.fromFile(OpenFlAssets.getPath(key));
			if (sound == null)
				output = Sound.fromFile(OpenFlAssets.getPath(key));
			else
				output = Sound.fromAudioBuffer(lime.media.AudioBuffer.fromVorbisFile(sound));
		}
		else
			output = Sound.fromFile(OpenFlAssets.getPath(key));

		sounds[path] = output;

		return sounds[path];
	}

	public static function sound(path:String, ?soundStreaming:Bool = false, returnString:Bool = false)
		return loadSound('sounds/$path', soundStreaming, returnString);

	public static function music(path:String, ?soundStreaming:Bool = false, ?returnString:Bool = false)
		return loadSound('music/$path', soundStreaming, returnString);

	public static function voices(song:String, ?char:String = '', ?returnString:Bool = false):Any
	{
		final songLowercase = StringTools.replace(song, " ", "-").toLowerCase() + '/Voices$char';
		return loadSound('songs/$songLowercase', true, returnString);
	}

	public static function inst(song:String, ?returnString:Bool = false):Any
	{
		final songLowercase = StringTools.replace(song, " ", "-").toLowerCase() + '/Inst';
		return loadSound('songs/$songLowercase', true, returnString);
	}

	public static function removeGraphic(path:String):Void
	{
		if (!graphics.exists(path))
			return;

		var graphic:FlxGraphic = graphics[path];

		if (graphic.useCount > 0.0)
			return;
		@:privateAccess
		if (graphic != null && graphic.bitmap != null && graphic.bitmap.__texture != null)
			graphic.bitmap.__texture.dispose();

		FlxG.bitmap.remove(graphic);

		graphics.remove(path);
		graphic = null;
	}

	public static function removeSound(path:String):Void
	{
		if (!sounds.exists(path))
			return;

		var sound:Sound = sounds[path];

		for (i in 0...FlxG.sound.list.length)
		{
			@:privateAccess
			{
				if (FlxG.sound.list.members[i]._sound == sound)
					return;
			}
		}

		OpenFlAssets.cache.removeSound(path);

		sounds.remove(path);
	}

	public static function clearGraphics():Void
	{
		@:privateAccess
		if (ToolkitAssets.instance._imageCache != null)
			for (key in ToolkitAssets.instance._imageCache.keys())
				ToolkitAssets.instance._imageCache.remove(key);

		for (key => value in graphics)
			removeGraphic(key);
	}

	public static function clearSounds():Void
	{
		for (key => value in sounds)
			removeSound(key);
	}

	#if mobile
	public static function trimGraphicsCache():Void
	{
		var entries = [for (key in graphics.keys()) key];
		if (entries.length <= maxCacheEntries)
			return;

		var overflow = entries.length - maxCacheEntries;
		for (i in 0...overflow)
			removeGraphic(entries[i]);
	}
	#end

	public static function runGC()
	{
		openfl.system.System.gc();
	}

	public static function clearCache():Void
	{
		clearGraphics();
		clearSounds();

		#if FEATURE_MODCORE
		polymod.Polymod.clearCache();
		#end
		runGC();
	}
}

package kec.util;

import openfl.utils.Assets as OpenFlAssets;
import flixel.graphics.frames.FlxBitmapFont;
import flixel.text.FlxBitmapText;
#if VIDEOS
import hxvlc.flixel.FlxVideo as VideoHandler;
import hxvlc.util.Handle;
#end
#if FEATURE_FILESYSTEM
import sys.io.File;
import Sys;
import sys.FileSystem;
#end
import haxe.io.Path;
import lime.utils.Assets as LimeAssets;

using StringTools;

class CoolUtil
{
	public static var defaultDifficulties:Array<String> = ['Easy', 'Normal', 'Hard'];
	public static var suffixDiffsArray:Array<String> = ['-easy', '', '-hard'];

	public static var customDifficulties:Array<String> = [];
	public static var defaultDifficulty:String = 'Normal';
	public static var noteShitArray:Array<String> = ['Alt', 'Hurt', 'Must Press'];

	public static var difficulties:Array<String> = getGlobalDiffs();

	public static var daPixelZoom:Float = 6;

	public static function formatToSongPath(path:String):String
	{
		return path.toLowerCase().replace(' ', '-');
	}

	public static function difficultyFromInt(difficulty:Int):String
	{
		return difficulties[difficulty];
	}

	public static function getDifficultyFilePath(?num:Int):String
	{
		if (num == null)
			num = PlayState.storyDifficulty;

		var fileSuffix:String = difficulties[num];
		fileSuffix = fileSuffix != defaultDifficulty ? '-' + fileSuffix : '';

		return formatToSongPath(fileSuffix);
	}

	public static function difficultyString():String
	{
		return difficulties[PlayState.storyDifficulty].toUpperCase();
	}

	static function getGlobalDiffs():Array<String>
	{
		var result:Array<String> = [];
		result = result.concat(defaultDifficulties);
		result = result.concat(customDifficulties);
		return result;
	}

	public static inline function boundTo(value:Float, min:Float, max:Float):Float
	{
		return Math.max(min, Math.min(max, value));
	}

	public static function lerp(base:Float, target:Float, progress:Float):Float
	{
		return base + progress * (target - base);
	}

	public static function smoothLerp(current:Float, target:Float, elapsed:Float, duration:Float, precision:Float = 0.01):Float
	{
		if (current == target)
			return target;

		var result:Float = lerp(current, target, 1 - Math.pow(precision, elapsed / duration));

		if (Math.abs(result - target) < precision * target)
			result = target;

		return result;
	}

	public static function listFromString(source:String):Array<String>
	{
		var lines:Array<String> = source.trim().split('\n');

		for (i in 0...lines.length)
			lines[i] = lines[i].trim();

		return lines;
	}

	public static function getSuffixFromDiff(diff:String):String
	{
		return diff != defaultDifficulty ? '-${diff.toLowerCase()}' : '';
	}

	public static function camLerpShit(lerp:Float):Float
	{
		return lerp * (FlxG.elapsed / (1 / 60));
	}

	public static function coolLerp(base:Float, target:Float, ratio:Float):Float
	{
		return base + camLerpShit(ratio) * (target - base);
	}

	public static inline function fpsLerp(a:Float, b:Float, k:Float, dt:Float):Float
	{
		return lerp(a, b, 1 - Math.pow(1 - k, dt * FlxG.elapsed));
	}

	public static function coolTextFile(path:String):Array<String>
	{
		var lines:Array<String>;

		try
		{
			lines = OpenFlAssets.getText(path).trim().split('\n');
		}
		catch (e)
		{
			return null;
		}

		for (i in 0...lines.length)
			lines[i] = lines[i].trim();

		return lines;
	}

	public static function coolStringFile(source:String):Array<String>
	{
		var lines:Array<String> = source.trim().split('\n');

		for (i in 0...lines.length)
			lines[i] = lines[i].trim();

		return lines;
	}

	public static function numberArray(max:Int, min:Int = 0):Array<Int>
	{
		var result:Array<Int> = [];
		for (i in min...max)
			result.push(i);
		return result;
	}

	public static inline function colorFromString(color:String):FlxColor
	{
		var strippedColor:String = ~/[\t\n\r]/g.split(color).join('').trim();
		if (strippedColor.startsWith('0x'))
			strippedColor = strippedColor.substr(2);

		var parsedColor:Null<FlxColor> = FlxColor.fromString(strippedColor);
		if (parsedColor == null)
			parsedColor = FlxColor.fromString('#$strippedColor');

		return parsedColor != null ? parsedColor : FlxColor.WHITE;
	}

	public static function readAssetsDirectoryFromLibrary(path:String, ?type:String, library:String = 'default', removePath:Bool = true):Array<String>
	{
		var lib = LimeAssets.getLibrary(library);
		var entries:Array<String> = lib.list(type);
		var result:Array<String> = [];

		for (entry in entries)
		{
			if (!entry.startsWith(path))
				continue;

			result.push(removePath ? entry.replace('$path/', '') : entry);
		}

		result.sort(Reflect.compare);

		return result;
	}

	public static inline function dominantColor(sprite:flixel.FlxSprite):Int
	{
		var countByColor:Map<Int, Int> = new Map();

		for (col in 0...sprite.frameWidth)
		{
			for (row in 0...sprite.frameHeight)
			{
				var pixel:FlxColor = sprite.pixels.getPixel32(col, row);
				if (pixel.alphaFloat <= 0.05)
					continue;

				var solidPixel:FlxColor = FlxColor.fromRGB(pixel.red, pixel.green, pixel.blue, 255);
				countByColor.set(solidPixel, (countByColor.exists(solidPixel) ? countByColor.get(solidPixel) : 0) + 1);
			}
		}

		countByColor.set(FlxColor.BLACK, 0);

		var maxCount:Int = 0;
		var maxKey:Int = 0;

		for (key => count in countByColor)
		{
			if (count >= maxCount)
			{
				maxCount = count;
				maxKey = key;
			}
		}

		return maxKey;
	}

	public static function expDecay(a:Float, b:Float, decay:Float):Float
	{
		return b + (a - b) * Math.exp(-decay * FlxG.elapsed);
	}

	public static inline function getFileStringFromPath(file:String):String
	{
		return Path.withoutDirectory(Path.withoutExtension(file));
	}
}

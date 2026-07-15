package;

import flixel.FlxGame;
import openfl.display.DisplayObject;
import haxe.ui.Toolkit;
import kec.objects.FrameCounter;
#if FEATURE_DISCORD
import kec.backend.Discord;
#end
import openfl.Lib;
import openfl.display.FPS;
import openfl.display.Sprite;
import openfl.events.Event;
import lime.app.Application;
#if VIDEOS
import hxvlc.util.Handle;
#end
#if (desktop || mobile)
import openfl.events.UncaughtErrorEvent;
import haxe.CallStack;
import haxe.io.Path;
import sys.FileSystem;
import sys.io.File;
import sys.io.Process;
import openfl.system.System;
#end
#if android
import openfl.ui.Keyboard;
import openfl.events.KeyboardEvent;
#end
import openfl.utils.AssetCache;

using StringTools;

class Main extends Sprite
{
	final game = {
		width: 1280,
		height: 720,
		initialState: Init,
		zoom: -1.0,
		framerate: 60,
		skipSplash: true,
		startFullscreen: false
	};

	public static var mainClassState:Class<FlxState> = Init;
	public static var focusMusicTween:FlxTween;
	public static var focused:Bool = true;

	public var hasWifi:Bool = true;

	var oldVol:Float = 1.0;
	var newVol:Float = 0.3;

	private var curGame:FlxGame;

	public static var gameContainer:Main = null;

	public var frameCounter:FrameCounter = null;

	public function new()
	{
		super();
		setupGame();
	}

	private function setupGame():Void
	{
		gameContainer = this;

		initHaxeUI();

		kec.backend.Debug.onInitProgram();

		frameCounter = new FrameCounter(10, 3, 0xFFFFFF);
		game.framerate = 60;
		curGame = new Game(game.width, game.height, game.initialState, game.framerate, game.skipSplash, game.startFullscreen);

		@:privateAccess
		curGame._customSoundTray = flixel.FunkinSoundTray;
		addChild(curGame);

		FlxG.fixedTimestep = false;

		#if !mobile
		addChild(frameCounter);
		fpsVisible(FlxG.save.data.fps);
		#end

		#if html5
		FlxG.autoPause = false;
		FlxG.mouse.visible = false;
		#end

		#if mobile
		FlxG.mouse.visible = false;
		FlxG.autoPause = false;
		#end

		#if VIDEOS
		Handle.initAsync();
		#end

		Debug.onGameStart();

		#if (desktop || mobile)
		Lib.current.loaderInfo.uncaughtErrorEvents.addEventListener(UncaughtErrorEvent.UNCAUGHT_ERROR, onCrash);
		#end

		#if desktop
		Application.current.window.onFocusOut.add(onWindowFocusOut);
		Application.current.window.onFocusIn.add(onWindowFocusIn);
		#end

		#if android
		stage.addEventListener(KeyboardEvent.KEY_DOWN, onAndroidKeyDown);
		#end
	}

	public function setFPSCap(cap:Int)
	{
		FlxG.updateFramerate = cap;
		FlxG.drawFramerate = FlxG.updateFramerate;
	}

	public inline function fpsVisible(visible:Bool)
		return gameContainer.frameCounter.visible = visible;

	public inline function setFPSPos(x:Int, y:Int)
	{
		gameContainer.frameCounter.x = x;
		gameContainer.frameCounter.y = y;
	}

	public inline function setFPSColor(col:Int)
		return gameContainer.frameCounter.textColor = col;

	public function checkInternetConnection()
	{
		Debug.logInfo('Checking Internet connection Through URL: "https://www.google.com".');
		var http = new haxe.Http("https://www.google.com");
		http.onStatus = function(status:Int)
		{
			switch status
			{
				case 200:
					hasWifi = true;
					Debug.logInfo('Connected.');
				default:
					hasWifi = false;
					Debug.logInfo('No Internet Connection.');
			}
		};

		http.onError = function(e)
		{
			hasWifi = false;
			Debug.logInfo('No Internet Connection.');
		}

		http.request();
	}

	#if (desktop || mobile)
	function onCrash(e:UncaughtErrorEvent):Void
	{
		var errMsg:String = "";
		var path:String;
		var callStack:Array<StackItem> = CallStack.exceptionStack(true);
		var dateNow:String = Date.now().toString();
		dateNow = dateNow.replace(" ", "_");
		dateNow = dateNow.replace(":", "'");
		#if mobile
		path = FEATURE_FILESYSTEM ? lime.system.System.applicationStorageDirectory + "/logs/Crashlog " + dateNow + ".txt" : "";
		#else
		path = "./logs/" + "Crashlog " + dateNow + ".txt";
		#end
		for (stackItem in callStack)
		{
			switch (stackItem)
			{
				case FilePos(s, file, line, column):
					errMsg += file + " (line " + line + ")\n";
				default:
					Sys.println(stackItem);
			}
		}
		errMsg += "\nUncaught Error: "
			+ "Version : "
			+ '${Constants.kecVer} Error Type: '
			+ e.error
			+
			"\nWoops! We fucked up somewhere! Report this window here : https://github.com/TheRealJake12/Kade-Engine-Community.git\n\n Why dont you join the discord while you're at it? : https://discord.gg/TKCzG5rVGf \n\n> Crash Handler written by: sqirra-rng";
		Sys.println(errMsg);
		#if FEATURE_LOGGING
		if (path != "")
		{
			var dir = Path.directory(path);
			if (!FileSystem.exists(dir))
				FileSystem.createDirectory(dir);
			File.saveContent(path, errMsg + "\n");
			Sys.println("Crash dump saved in " + Path.normalize(path));
		}
		#end
		#if desktop
		Application.current.window.alert(errMsg, "Error!");
		#end
		Sys.exit(1);
	}
	#end

	#if desktop
	function onWindowFocusOut()
	{
		focused = false;

		oldVol = FlxG.sound.volume;
		if (oldVol > 0.3)
			newVol = 0.3;
		else
		{
			if (oldVol > 0.1)
				newVol = 0.1;
			else
				newVol = 0;
		}

		if (focusMusicTween != null)
			focusMusicTween.cancel();
		focusMusicTween = FlxTween.tween(FlxG.sound, {volume: newVol}, 0.5);

		FlxG.drawFramerate = 60;
	}

	function onWindowFocusIn()
	{
		FlxTimer.wait(0.2, function()
		{
			focused = true;
		});

		if (focusMusicTween != null)
			focusMusicTween.cancel();

		focusMusicTween = FlxTween.tween(FlxG.sound, {volume: oldVol}, 0.5);

		gameContainer.setFPSCap(FlxG.save.data.fpsCap);
	}
	#end

	#if android
	function onAndroidKeyDown(e:KeyboardEvent):Void
	{
		if (e.keyCode == Keyboard.BACK)
		{
			e.preventDefault();
			onAndroidBackPressed();
		}
	}

	function onAndroidBackPressed():Void
	{
		if (Std.isOfType(FlxG.state, MusicBeatState))
			cast(FlxG.state, MusicBeatState).onAndroidBack();
	}
	#end

	function initHaxeUI():Void
	{
		Toolkit.init();
		Toolkit.theme = 'dark';
		Toolkit.autoScale = false;
	}

	@:noCompletion private override function __hitTest(x:Float, y:Float, shapeFlag:Bool, stack:Array<DisplayObject>, interactiveOnly:Bool,
			hitObject:DisplayObject):Bool
		return true;

	@:noCompletion override private function __hitTestHitArea(x:Float, y:Float, shapeFlag:Bool, stack:Array<DisplayObject>, interactiveOnly:Bool,
			hitObject:DisplayObject):Bool
		return true;

	@:noCompletion private override function __hitTestMask(x:Float, y:Float):Bool
		return true;
}

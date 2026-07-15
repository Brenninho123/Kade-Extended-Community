package kec.mobile.backend;

#if FEATURE_FILESYSTEM
import sys.FileSystem;
import sys.io.File;
import sys.io.FileOutput;
import haxe.io.Bytes;
import haxe.io.Path;
import haxe.zip.Compress;
import haxe.zip.Uncompress;
import lime.system.System as LimeSystem;
#end
#if android
import lime.system.JNI;
#end

using StringTools;

class StorageUtil
{
	static var initialized:Bool = false;
	static var baseDir:String = '';
	static var cache:Map<String, Bytes> = new Map();

	public static var maxCacheEntries:Int = 25;
	public static var compressionEnabled:Bool = true;

	public static function initialize():Void
	{
		if (initialized)
			return;

		#if FEATURE_FILESYSTEM
		baseDir = resolveStorageDirectory();

		if (!FileSystem.exists(baseDir))
			FileSystem.createDirectory(baseDir);

		if (!FileSystem.exists(backupDir()))
			FileSystem.createDirectory(backupDir());
		#end

		initialized = true;
	}

	static function resolveStorageDirectory():String
	{
		#if android
		var external:String = getAndroidExternalPath();
		if (external != null && external.length > 0)
			return Path.addTrailingSlash(external) + 'KadeExtended';
		#end

		return Path.addTrailingSlash(LimeSystem.applicationStorageDirectory) + 'storage';
	}

	#if android
	static function getAndroidExternalPath():String
	{
		try
		{
			var handle = JNI.createStaticMethod('android/os/Environment', 'getExternalStorageDirectory', '()Ljava/io/File;');
			var fileObj:Dynamic = handle();
			var toString = JNI.createMemberMethod('java/io/File', 'getAbsolutePath', '()Ljava/lang/String;');
			return toString(fileObj);
		}
		catch (e)
		{
			return null;
		}
	}
	#end

	static inline function backupDir():String
		return Path.addTrailingSlash(baseDir) + '.backup';

	static inline function keyToPath(key:String):String
		return Path.addTrailingSlash(baseDir) + sanitizeKey(key) + '.dat';

	static inline function keyToBackupPath(key:String):String
		return Path.addTrailingSlash(backupDir()) + sanitizeKey(key) + '.dat';

	static function sanitizeKey(key:String):String
	{
		var invalidChars = ~/[^a-zA-Z0-9_\-.]/g;
		return invalidChars.replace(key, '_');
	}

	public static function write(key:String, data:Bytes, keepBackup:Bool = true):Bool
	{
		#if FEATURE_FILESYSTEM
		if (!initialized)
			initialize();

		var path:String = keyToPath(key);

		try
		{
			if (keepBackup && FileSystem.exists(path))
			{
				var existing:Bytes = File.getBytes(path);
				File.saveBytes(keyToBackupPath(key), existing);
			}

			var payload:Bytes = compressionEnabled ? Compress.run(data, 6) : data;

			var tempPath:String = path + '.tmp';
			File.saveBytes(tempPath, payload);
			if (FileSystem.exists(path))
				FileSystem.deleteFile(path);
			FileSystem.rename(tempPath, path);

			cache.set(key, data);
			trimCache();

			return true;
		}
		catch (e)
		{
			return false;
		}
		#else
		return false;
		#end
	}

	public static function writeString(key:String, data:String, keepBackup:Bool = true):Bool
	{
		return write(key, Bytes.ofString(data), keepBackup);
	}

	public static function writeJSON(key:String, data:Dynamic, keepBackup:Bool = true):Bool
	{
		return writeString(key, haxe.Json.stringify(data), keepBackup);
	}

	public static function read(key:String):Bytes
	{
		#if FEATURE_FILESYSTEM
		if (!initialized)
			initialize();

		if (cache.exists(key))
			return cache.get(key);

		var path:String = keyToPath(key);

		if (!FileSystem.exists(path))
			return null;

		try
		{
			var raw:Bytes = File.getBytes(path);
			var data:Bytes = compressionEnabled ? Uncompress.run(raw) : raw;
			cache.set(key, data);
			trimCache();
			return data;
		}
		catch (e)
		{
			return readFromBackup(key);
		}
		#else
		return null;
		#end
	}

	#if FEATURE_FILESYSTEM
	static function readFromBackup(key:String):Bytes
	{
		var backupPath:String = keyToBackupPath(key);

		if (!FileSystem.exists(backupPath))
			return null;

		try
		{
			var raw:Bytes = File.getBytes(backupPath);
			return compressionEnabled ? Uncompress.run(raw) : raw;
		}
		catch (e)
		{
			return null;
		}
	}
	#end

	public static function readString(key:String):String
	{
		var data:Bytes = read(key);
		return data != null ? data.toString() : null;
	}

	public static function readJSON(key:String):Dynamic
	{
		var raw:String = readString(key);
		if (raw == null)
			return null;

		try
		{
			return haxe.Json.parse(raw);
		}
		catch (e)
		{
			return null;
		}
	}

	public static function exists(key:String):Bool
	{
		#if FEATURE_FILESYSTEM
		if (!initialized)
			initialize();

		return cache.exists(key) || FileSystem.exists(keyToPath(key));
		#else
		return false;
		#end
	}

	public static function delete(key:String):Bool
	{
		#if FEATURE_FILESYSTEM
		if (!initialized)
			initialize();

		cache.remove(key);

		var path:String = keyToPath(key);

		if (!FileSystem.exists(path))
			return false;

		try
		{
			FileSystem.deleteFile(path);
			return true;
		}
		catch (e)
		{
			return false;
		}
		#else
		return false;
		#end
	}

	public static function listKeys():Array<String>
	{
		#if FEATURE_FILESYSTEM
		if (!initialized)
			initialize();

		var result:Array<String> = [];

		if (!FileSystem.exists(baseDir))
			return result;

		for (entry in FileSystem.readDirectory(baseDir))
		{
			if (entry.endsWith('.dat'))
				result.push(entry.substr(0, entry.length - 4));
		}

		return result;
		#else
		return [];
		#end
	}

	public static function getUsedBytes():Int
	{
		#if FEATURE_FILESYSTEM
		if (!initialized)
			initialize();

		var total:Int = 0;

		if (!FileSystem.exists(baseDir))
			return 0;

		for (entry in FileSystem.readDirectory(baseDir))
		{
			var fullPath:String = Path.addTrailingSlash(baseDir) + entry;
			if (!FileSystem.isDirectory(fullPath))
				total += FileSystem.stat(fullPath).size;
		}

		return total;
		#else
		return 0;
		#end
	}

	static function trimCache():Void
	{
		var keys = [for (k in cache.keys()) k];
		if (keys.length <= maxCacheEntries)
			return;

		var overflow = keys.length - maxCacheEntries;
		for (i in 0...overflow)
			cache.remove(keys[i]);
	}

	public static function clearCache():Void
	{
		cache = new Map();
	}

	public static function clearAll(includeBackups:Bool = false):Void
	{
		#if FEATURE_FILESYSTEM
		if (!initialized)
			initialize();

		clearCache();

		if (FileSystem.exists(baseDir))
			for (entry in FileSystem.readDirectory(baseDir))
			{
				var fullPath:String = Path.addTrailingSlash(baseDir) + entry;
				if (!FileSystem.isDirectory(fullPath))
					FileSystem.deleteFile(fullPath);
			}

		if (includeBackups && FileSystem.exists(backupDir()))
			for (entry in FileSystem.readDirectory(backupDir()))
			{
				var fullPath:String = Path.addTrailingSlash(backupDir()) + entry;
				if (!FileSystem.isDirectory(fullPath))
					FileSystem.deleteFile(fullPath);
			}
		#end
	}
}

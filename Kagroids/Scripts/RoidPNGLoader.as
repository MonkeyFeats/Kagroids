// BasePNGLoader.as
// NSFL if you don't unzoom it out in your editor

// Note for modders upgrading their mod, handlePixel's signature has changed recently!

#include "RoidMapColors.as";
#include "LoaderUtilities.as";

enum WAROffset
{
	autotile_offset = 0,
	tree_offset,
	bush_offset,
	grain_offset,
	spike_offset,
	ladder_offset,
	offsets_count
};

//global
Random@ map_random = Random();

class PNGLoader
{
	PNGLoader()
	{
		offsets = int[][](offsets_count, int[](0));
	}

	CFileImage@ image;
	CMap@ map;

	int[][] offsets;

	int current_offset_count;

	bool loadMap(CMap@ _map, const string& in filename)
	{
		@map = _map;
		@map_random = Random();

		if(!getNet().isServer())
		{
			SetupMap(0, 0);
			SetupBackgrounds();

			return true;
		}

		@image = CFileImage( filename );

		if(image.isLoaded())
		{
			SetupMap(image.getWidth(), image.getHeight());
			SetupBackgrounds();

			while(image.nextPixel())
			{
				const SColor pixel = image.readPixel();
				const int offset = image.getPixelOffset();

				// Optimization: check if the pixel color is the sky color
				// We do this before calling handlePixel because it is overriden, and to avoid a SColor copy
				if (pixel.color != map_colors::sky)
				{
					handlePixel(pixel, offset);
				}

				getNet().server_KeepConnectionsAlive();
			}

			return true;
		}
		return false;
	}

	// Queue an offset to be autotiled
	void autotile(int offset)
	{
		offsets[autotile_offset].push_back(offset);
	}

	void handlePixel(const SColor &in pixel, int offset)
	{
		switch (pixel.color)
		{
		// Tiles
		case map_colors::tile_ground:           map.SetTile(offset, CMap::tile_ground);           break;

		
		// Main spawns
		case map_colors::blue_main_spawn:   AddMarker(map, offset, "blue main spawn"); break;
		case map_colors::red_main_spawn:    AddMarker(map, offset, "red main spawn");  break;
		// Normal spawns
			case map_colors::blue_spawn:     AddMarker(map, offset, "blue spawn");   break;
			case map_colors::red_spawn:      AddMarker(map, offset, "red spawn");    break;
			/*case map_colors::green_spawn:  AddMarker(map, offset, "green spawn");  break;*/ // same as grass...?
			case map_colors::purple_spawn:   AddMarker(map, offset, "purple spawn"); break;
			/*case map_colors::orange_spawn: AddMarker(map, offset, "orange spawn"); break;*/ // same as dirt...?
			case map_colors::aqua_spawn:     AddMarker(map, offset, "aqua spawn");   break;
			case map_colors::teal_spawn:     AddMarker(map, offset, "teal spawn");   break;
			case map_colors::gray_spawn:     AddMarker(map, offset, "gray spawn");   break;

			default: {}
		

		};
	}

	void SetupMap(int width, int height)
	{
		map.CreateTileMap(width, height, 256.0f, "Sprites/world.png");
	}

	void SetupBackgrounds()
	{
		// sky
		map.CreateSky(color_black);
		//map.CreateSkyGradient("Sprites/skygradient.png"); // override sky color with gradient

		// background
		//map.AddBackground("Sprites/whiteneb.png", Vec2f(0.0f, -18.0f), Vec2f(0.3f, 0.3f), color_white);

		// fade in
		SetScreenFlash(255,   0,   0,   0);
	}


void PlaceMostLikelyTile(CMap@ map, int offset)
{
	const TileType up = map.getTile(offset - map.tilemapwidth).type;
	const TileType down = map.getTile(offset + map.tilemapwidth).type;
	const TileType left = map.getTile(offset - 1).type;
	const TileType right = map.getTile(offset + 1).type;

	if (up != CMap::tile_empty)
	{
		const TileType[] neighborhood = { up, down, left, right };

		if ((neighborhood.find(CMap::tile_castle) != -1) ||
		    (neighborhood.find(CMap::tile_castle_back) != -1))
		{
			map.SetTile(offset, CMap::tile_castle_back);
		}
		else if ((neighborhood.find(CMap::tile_wood) != -1) ||
		         (neighborhood.find(CMap::tile_wood_back) != -1))
		{
			map.SetTile(offset, CMap::tile_wood_back );
		}
		else if ((neighborhood.find(CMap::tile_ground) != -1) ||
		         (neighborhood.find(CMap::tile_ground_back) != -1))
		{
			map.SetTile(offset, CMap::tile_ground_back);
		}
	}
}

u8 getTeamFromChannel(u8 channel)
{
	// only the bits we want
	channel &= 0x0F;

	return (channel > 7)? 255 : channel;
}

u8 getChannelFromTeam(u8 team)
{
	return (team > 7)? 0x0F : team;
}

u16 getAngleFromChannel(u8 channel)
{
	// only the bits we want
	channel &= 0x30;

	switch(channel)
	{
		case 16: return 90;
		case 32: return 180;
		case 48: return 270;
	}

	return 0;
}

u8 getChannelFromAngle(u16 angle)
{
	switch(angle)
	{
		case  90: return 16;
		case 180: return 32;
		case 270: return 48;
	}

	return 0;
}

Vec2f getSpawnPosition(CMap@ map, int offset)
{
	Vec2f pos = map.getTileWorldPosition(offset);
	f32 tile_offset = map.tilesize * 0.5f;
	pos.x += tile_offset;
	pos.y += tile_offset;
	return pos;
}

CBlob@ spawnBlob(CMap@ map, const string &in name, u8 team, Vec2f position)
{
	return server_CreateBlob(name, team, position);
}

CBlob@ spawnBlob(CMap@ map, const string &in name, u8 team, Vec2f position, const bool fixed)
{
	CBlob@ blob = server_CreateBlob(name, team, position);
	blob.getShape().SetStatic(fixed);

	return blob;
}

CBlob@ spawnBlob(CMap@ map, const string &in name, u8 team, Vec2f position, s16 angle)
{
	CBlob@ blob = server_CreateBlob(name, team, position);
	blob.setAngleDegrees(angle);

	return blob;
}

CBlob@ spawnBlob(CMap@ map, const string &in name, u8 team, Vec2f position, s16 angle, const bool fixed)
{
	CBlob@ blob = spawnBlob(map, name, team, position, angle);
	blob.getShape().SetStatic(fixed);

	return blob;
}

CBlob@ spawnBlob(CMap@ map, const string& in name, int offset, u8 team = 255, bool attached_to_map = false, Vec2f posOffset = Vec2f_zero, s16 angle = 0)
{
	return spawnBlob(map, name, team, getSpawnPosition(map, offset) + posOffset, angle, attached_to_map);
}

CBlob@ spawnVehicle(CMap@ map, const string& in name, int offset, int team = -1)
{
	CBlob@ blob = server_CreateBlob(name, team, getSpawnPosition( map, offset));
	if(blob !is null)
	{
		blob.RemoveScript("DecayIfLeftAlone.as");
	}
	return blob;
}

void AddMarker(CMap@ map, int offset, const string& in name)
{
	map.AddMarker(map.getTileWorldPosition(offset), name);
}
}
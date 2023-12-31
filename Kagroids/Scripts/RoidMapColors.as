// LoaderColors.as

//////////////////////////////////////
// Alpha channel documentation
//////////////////////////////////////

// The last bit (128) is always true for comp-
// atability with most image editing software
// to ensure a minimum alpha of 128.

// The second to last bit (64) is always false
// so loadMap() can recognize when to branch
// to alpha functionality.

// The first six bits are free to be used for
// the pre-set functionality below or your own
// custom functionality.

// Example of a purple team diode rotated 90°
// purple(3) + right(16) + last bit(128) = 147
// SColor decimal(147, 255, 0, 255);
// SColor hexadecimal(0x93FF00FF);

// | num | team     | binary    | hex  | dec |
// -------------------XX---vvvv---------------
// |   0 | blue     | 0000 0000 | 0x00 |   0 |
// |   1 | red      | 0000 0001 | 0x01 |   1 |
// |   2 | green    | 0000 0010 | 0x02 |   2 |
// |   3 | purple   | 0000 0011 | 0x03 |   3 |
// |   4 | orange   | 0000 0100 | 0x04 |   4 |
// |   5 | teal     | 0000 0101 | 0x05 |   5 |
// |   6 | royal    | 0000 0110 | 0x06 |   6 |
// |   7 | stone    | 0000 0111 | 0x07 |   7 |
// | 255 | neutral  | 0000 1111 | 0x0F |  15 |

// | deg | dir      | binary    | hex  | dec |
// -------------------XXvv--------------------
// |   0 | up       | 0000 0000 | 0x00 |   0 |
// |  90 | right    | 0001 0000 | 0x10 |  16 |
// | 180 | down     | 0010 0000 | 0x20 |  32 |
// | 270 | left     | 0011 0000 | 0x30 |  48 |

// Methods for fetching useable information from
// the alpha channel.

// u8 getTeamFromChannel(u8 channel)
// u8 getChannelFromTeam(u8 team)

// u16 getAngleFromChannel(u8 channel)
// u8 getChannelFromAngle(u16 angle)

namespace map_colors
{
	enum color
	{
		// TILES
		tile_ground            = 0xFFcbdbfc, // ARGB(255, 132,  71,  21);
		tile_ground_back       = 0xFF3B1406, // ARGB(255,  59,  20,   6);
		tile_stone             = 0xFF8B6849, // ARGB(255, 139, 104,  73);
		tile_thickstone        = 0xFF42484B, // ARGB(255,  66,  72,  75);
		tile_bedrock           = 0xFF2D342D, // ARGB(255,  45,  52,  45);
		tile_gold              = 0xFFFEA53D, // ARGB(255, 254, 165,  61);
		tile_castle            = 0xFF647160, // ARGB(255, 100, 113,  96);
		tile_castle_back       = 0xFF313412, // ARGB(255,  49,  52,  18);
		tile_castle_moss       = 0xFF648F60, // ARGB(255, 100, 143,  96);
		tile_castle_back_moss  = 0xFF315212, // ARGB(255,  49,  82,  18);
		tile_ladder            = 0xFF2B1509, // ARGB(255,  43,  21,   9);
		tile_ladder_ground     = 0xFF42240B, // ARGB(255,  66,  36,  11);
		tile_ladder_castle     = 0xFF432F11, // ARGB(255,  67,  47,  17);
		tile_ladder_wood       = 0xFF453911, // ARGB(255,  69,  57,  17);
		tile_grass             = 0xFF649B0D, // ARGB(255, 100, 155,  13);
		tile_wood              = 0xFFC48715, // ARGB(255, 196, 135,  21);
		tile_wood_back         = 0xFF552A11, // ARGB(255,  85,  42,  17);

		// OTHER
		sky                    = 0xFF222034, // ARGB(255, 165, 189, 200);
		unused                 = 0xFF222034, // ARGB(255, 165, 189, 200);

		// MARKERS
		blue_main_spawn        = 0xFF00FFFF, // ARGB(255,   0, 255, 255);
		red_main_spawn         = 0xFFFF0000, // ARGB(255, 255,   0,   0);
		green_main_spawn       = 0xFF9DCA22, // ARGB(255, 157, 202,  34);
		purple_main_spawn      = 0xFFD379E0, // ARGB(255, 211, 121, 224);
		orange_main_spawn      = 0xFFCD6120, // ARGB(255, 205,  97,  32);
		aqua_main_spawn        = 0xFF2EE5A2, // ARGB(255,  46, 229, 162);
		teal_main_spawn        = 0xFF5F84EC, // ARGB(255,  95, 132, 236);
		gray_main_spawn        = 0xFFC4CFA1, // ARGB(255, 196, 207, 161);
		blue_spawn             = 0xFF00C8C8, // ARGB(255,   0, 200, 200);
		red_spawn              = 0xFFC80000, // ARGB(255, 200,   0,   0);
		green_spawn            = 0xFF649B0D, // ARGB(255, 100, 155,  13);
		purple_spawn           = 0xFF9E3ACC, // ARGB(255, 158,  58, 204);
		orange_spawn           = 0xFF844715, // ARGB(255, 132,  71,  21);
		aqua_spawn             = 0xFF4F9B7F, // ARGB(255,  79, 155, 127);
		teal_spawn             = 0xFF4149F0, // ARGB(255,  65,  73, 240);
		gray_spawn             = 0xFF97A792, // ARGB(255, 151, 167, 146);
	};
}

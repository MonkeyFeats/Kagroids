//Tile Common
//#include "CustomMap.as";

bool isTouchingLand( Vec2f pos )
{
	CMap@ map = getMap();
	u16 tileType = map.getTile( pos ).type;

	return false;
}

bool isTouchingRock( Vec2f pos )
{
	CMap@ map = getMap();
	u16 tileType = map.getTile( pos ).type;

	return false;
}

bool isTouchingShoal( Vec2f pos )
{
	CMap@ map = getMap();
	u16 tileType = map.getTile( pos ).type;

	return false;
}

bool isInWater( Vec2f pos )
{
	CMap@ map = getMap();
	u16 tileType = map.getTile( pos ).type;

	return false;
}
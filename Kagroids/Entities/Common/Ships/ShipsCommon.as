shared class Ship
{
	u32 id;
	ShipBlock[] blocks;
	Vec2f pos, vel;
	f32 angle, angle_vel;
	Vec2f old_pos, old_vel;
	f32 old_angle;
	f32 mass, carryMass;
	CBlob@ centerBlock;
	bool initialized;	
	uint soundsPlayed;
	string owner;
	bool isMothership;
	
	Vec2f net_pos, net_vel;
	f32 net_angle, net_angle_vel;

	Ship(){
		angle = angle_vel = old_angle = mass = carryMass = 0.0f;
		initialized = false;
		isMothership = false;
		@centerBlock = null;
		soundsPlayed = 0;
		owner = "";
	}
};

shared class ShipBlock
{
	u16 blobID;
	Vec2f offset;
	f32 angle_offset;
};

Ship@ getShip( const int colorIndex )
{
	Ship[]@ ships;
	if (getRules().get( "ships", @ships ))
		if (colorIndex > 0 && colorIndex <= ships.length){
			return ships[colorIndex-1];
		}
	return null;
}

Ship@ getShip( CBlob@ this )
{
	CBlob@[] blobsInRadius;	   
	if (getMap().getBlobsInRadius( this.getPosition(), 1.0f, @blobsInRadius )) 
	{
		for (uint i = 0; i < blobsInRadius.length; i++)
		{
			CBlob @b = blobsInRadius[i];
            const int color = b.getShape().getVars().customData;
            if (color > 0)
            {
            	return getShip(color);
            }
		}
	}
    return null;
}

CBlob@ getShipBlob( CBlob@ this )
{
	CBlob@ b = null;
	f32 mDist = 9999;
	CBlob@[] blobsInRadius;	   
	if (getMap().getBlobsInRadius( this.getPosition(), 1.0f, @blobsInRadius ))//custom getShipBlob();
		for (uint i = 0; i < blobsInRadius.length; i++)
			if (blobsInRadius[i].getShape().getVars().customData > 0)
			{
				f32 dist = this.getDistanceTo( blobsInRadius[i] );
				if ( dist < mDist )
				{
					@b = blobsInRadius[i];
					mDist = dist;
				}
			}
	return b;
}

Vec2f SnapToGrid( Vec2f pos )
{
    pos.x = Maths::Round(pos.x / 8.0f);
    pos.y = Maths::Round(pos.y / 8.0f);
    pos.x *= 8;
    pos.y *= 8;
    return pos;
}

void SetNextId( CRules@ this, Ship@ ship )
{
	ship.id = this.get_u32("ships id")+1;
	this.set_u32("ships id", ship.id);
}

CBlob@ getMothership( const u8 team )
{
    CBlob@[] ships;
    getBlobsByTag( "mothership", @ships );
    for (uint i=0; i < ships.length; i++)
    {
        CBlob@ ship = ships[i];  
        if (ship.getTeamNum() == team)
            return ship;
    }
    return null;
}

CBlob@ getMothership( CBlob@ this )
{
	CBlob@ core = null;
	const int color = this.getShape().getVars().customData;
	if ( color == 0 ) return core;

	CBlob@[] cores;
	getBlobsByTag( "mothership", cores );
	
	for ( int i = 0; i < cores.length; i++ )
		if ( cores[i].getShape().getVars().customData == color )
			@core = cores[i];
	
	return core;
}

bool isMothership( CBlob@ this )
{
	const int color = this.getShape().getVars().customData;
	if ( color == 0 ) return false;
	
	Ship@ ship = getShip( color );
	if ( ship !is null )
		return ship.isMothership;
	else
		return false;
}

bool blocksOverlappingShip( CBlob@[]@ blocks )
{
    bool result = false;
    for (uint i = 0; i < blocks.length; ++i)
    {
        CBlob @block = blocks[i];
        if (blockOverlappingShip( block ))
            result = true;
    }
    return result; 
}

bool blockOverlappingShip( CBlob@ blob )
{
    CBlob@[] overlapping;
    if ( getMap().getBlobsInRadius( blob.getPosition(), 8.0f, @overlapping ) )
    {
        for (uint i = 0; i < overlapping.length; i++)
        {
            CBlob@ b = overlapping[i];
            int color = b.getShape().getVars().customData;
            if (color > 0)
            {
                if ((b.getPosition() - blob.getPosition()).getLength() < blob.getRadius()*0.4f)
                    return true;
            }
        }
    }
    return false;
}

bool coreLinkedDirectional( CBlob@ this, u16 token, Vec2f corePos )//checks if the block leads up to a core. doesn't follow up couplings/repulsors. accounts for core position
{
	if ( this.hasTag( "mothership" ) )
		return true;

	this.set_u16( "checkToken", token );
	bool childsLinked = false;
	Vec2f thisPos = this.getPosition();
	
	CBlob@[] overlapping;
	if ( this.getOverlapping( @overlapping ) )
	{
		f32 minDist = 99999.0f;
		f32 minDist2;
		CBlob@[] optimal;
		for ( int i = 0; i < overlapping.length; i++ )
		{
			CBlob@ b = overlapping[i];
			Vec2f bPos = b.getPosition();
			
			f32 coreDist = ( bPos - corePos ).LengthSquared();
			if ( b.get_u16( "checkToken" ) != token && ( bPos - thisPos ).LengthSquared() < 78 && !b.hasTag( "removable" ) && b.getName() == "block" )//maybe should do a color > 0 check
			{
				if ( coreDist <= minDist )
				{
					optimal.insertAt( 0, b );
					minDist2 = minDist;	
					minDist = coreDist;
				}
				else	if ( coreDist <= minDist2 )
				{
					optimal.insertAt( 0, b );
					minDist2 = coreDist;
				}
				else
					optimal.push_back(b);
			}
		}
		
		for ( int i = 0; i < optimal.length; i++ )
		{
			//print( ( optimal[i].hasTag( "mothership" ) ? "[>] " : "[o] " ) + optimal[i].getNetworkID() );
			if ( coreLinkedDirectional( optimal[i], token, corePos ) )
			{
				childsLinked = true;
				break;
			}
		}
	}
		
	return childsLinked;
}

bool coreLinked( CBlob@ this, u16 token )//use directional one
{
	if ( this.hasTag( "mothership" ) )
		return true;

	this.set_u16( "checkToken", token );
	bool childsLinked = false;
	CBlob@[] overlapping;
	this.getOverlapping( @overlapping );
	for ( int i = 0; i < overlapping.length; i++ )
	{
		CBlob@ b = overlapping[i];
		//if ( !b.hasTag( "removable" ) && b.get_u16( "checkToken" ) != token && b.getName() == "block" && b.getDistanceTo(this) < 8.8  ) print( ( b.hasTag( "mothership" ) ? "[>] " : "[o] " ) + b.getNetworkID() );
		if ( !b.hasTag( "removable" ) && b.get_u16( "checkToken" ) != token
            && b.getName() == "block"
            && b.getDistanceTo(this) < 8.8
			&& coreLinked( b, token ) )
		{
			childsLinked = true;
			break;
		}
	}
	
	return childsLinked;
}
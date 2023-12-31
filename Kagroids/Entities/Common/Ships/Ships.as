#include "ShipsCommon.as"
#include "BlockCommon.as"
#include "AccurateSoundPlay.as"

const f32 VEL_DAMPING = 1.0f;
const f32 ANGLE_VEL_DAMPING = 0.998;
const uint FORCE_UPDATE_TICKS = 21;
f32 UPDATE_DELTA_SMOOTHNESS = 32.0f;//~16-64

uint color;
bool updatedThisTick = false;
void onInit( CRules@ this )
{
	Ship[] ships;
	this.set("ships", ships);
	this.addCommandID("ships sync");
	this.addCommandID("ships update");
	this.set_u32("ships id", 0);
	this.set_bool("dirty ships", true);
}

void onRestart( CRules@ this )
{
	this.clear("ships");
	this.set_bool("dirty ships", true);
}

void onTick( CRules@ this )
{
	GravitationalForces(this);

	bool full_sync = false;				
	if (getNet().isServer())
	{
		const int time = getMap().getTimeSinceStart();
		if (time < 2) // errors are generated when done on first game tick
			return;

		const bool dirty = this.get_bool("dirty ships");
		if (dirty)
		{
			GenerateShips( this );			
			setUpdateSeatsArrays();
			this.set_bool("dirty ships", false);
			full_sync = true;
		}

		UpdateShips( this, true, full_sync );
		Synchronize( this, full_sync );
	}
	else
		UpdateShips( this );//client-side integrate
		
	updatedThisTick = false;
}

void GravitationalForces(CRules@ this)
{
	Ship[]@ ships;
	this.get( "ships", @ships );	
	for (uint i = 0; i < ships.length; ++i)
	{
		Ship@ ship = ships[i];
		if (ship !is null)
		{
			Vec2f PlanetCenter(11*128, 11*128);
			const float Gravity = -9.81;
			//const float G = 6.67428*(67) *-1 m^3/1000*s^2;
			//Earths mass = 5,972,000,000,000,000,000,000 tons
			//The International Space Station is approximately 108.5 meters by 72.8 meters & weighs around 450 tons
			const float PlanetMass = 597.2;
			double ShipMass = ship.mass;


			//distance from earths center to the surface = 6360km
			//satalittes orbit earth between 6666 km - 35500 km, 17700km is good for GPS&
			double orbitDistance = Maths::Max((PlanetCenter-ship.pos).Length()*8, 1);
			
			// Gravity*((Mass1*Mass2)/DistanceToMassCenter)
			double gravforce = (Gravity*PlanetMass*ShipMass)/orbitDistance;
			//print("gravforce "+gravforce);

			Vec2f PlanetaryInetia(gravforce, 0 );
			double ShipAngleToPlanet = (ship.pos-PlanetCenter).Angle();
			PlanetaryInetia.RotateByDegrees(-ShipAngleToPlanet);
			
			ship.vel += PlanetaryInetia/600;
		}
	}
}

void GenerateShips( CRules@ this )
{
	StoreVelocities( this );

	CBlob@[] blocks;
	this.clear("ships");
	if (getBlobsByName( "block", @blocks ))
	{	
		color = 0;
		for (uint i = 0; i < blocks.length; ++i)
		{
			if (blocks[i].getShape().getVars().customData > 0)
				blocks[i].getShape().getVars().customData = 0;			
		}

		for (uint i = 0; i < blocks.length; ++i)
		{
			CBlob@ b = blocks[i];
			if (b.getShape().getVars().customData == 0)
			{
				color++;

				Ship ship;
				SetNextId( this, @ship );
				this.push("ships", ship);
				Ship@ p_ship;
				this.getLast( "ships", @p_ship );

				ColorBlocks( b, p_ship );			
			}
		}	
		for (uint i = 0; i < blocks.length; ++i)
		{
			CBlob@ b = blocks[i];
			b.set_u16("last color", b.getShape().getVars().customData);				
		}
	}

	//print("Generated " + color + " ships");
}

void ColorBlocks( CBlob@ blob, Ship@ ship )
{
	blob.getShape().getVars().customData = color;
	
	ShipBlock ship_block;
	ship_block.blobID = blob.getNetworkID();
	ship.blocks.push_back(ship_block);

	CBlob@[] overlapping;
    if (blob.getOverlapping( @overlapping ))
    {
        for (uint i = 0; i < overlapping.length; i++)
        {
            CBlob@ b = overlapping[i];
			
            if ( b.getShape().getVars().customData == 0 
				&& b.getName() == "block" 
				&& ( b.getPosition() - blob.getPosition() ).LengthSquared() < 78 // avoid "corner" overlaps
				&& ( (b.get_u16("last color") == blob.get_u16("last color")) || (b.getSprite().getFrame() == Block::COUPLING) || (blob.getSprite().getFrame() == Block::COUPLING) 
				|| ((getGameTime() - b.get_u32( "placedTime" )) < 10) || ((getGameTime() - blob.get_u32( "placedTime" )) < 10) 
				|| (getMap().getTimeSinceStart() < 100) )) 
				{
					ColorBlocks( b, ship ); 
				}
        }
    }
}

void InitShip( Ship @ship )//called for all ships after a block is placed or collides
{
	Vec2f center, vel;
	f32 angle_vel = 0.0f;
	if ( ship.centerBlock is null )//when clients InitShip(), they should have key values pre-synced. no need to calculate
	{
		//get ship vels (stored previously on all blobs), center
		for (uint b_iter = 0; b_iter < ship.blocks.length; ++b_iter)
		{
			CBlob@ b = getBlobByNetworkID( ship.blocks[b_iter].blobID );
			if (b !is null)
			{
				center += b.getPosition();
				if (b.getVelocity().LengthSquared() > 0.0f)
				{
					vel = b.getVelocity();
					angle_vel = b.getAngularVelocity();			
				}
			}
		}
		center /= float(ship.blocks.length);

		//find center block and mass and if it's mothership
		f32 totalMass = 0.0f;
		f32 maxDistance = 999999.9f;
		for (uint b_iter = 0; b_iter < ship.blocks.length; ++b_iter)
		{
			CBlob@ b = getBlobByNetworkID( ship.blocks[b_iter].blobID );
			if (b !is null)
			{
				Vec2f vec = b.getPosition() - center;
				f32 dist = vec.LengthSquared();
				if (dist < maxDistance){
					maxDistance = dist;
					@ship.centerBlock = b;
				}
				//mass calculation
				totalMass += b.get_f32( "weight" );
				
				if ( b.hasTag( "mothership" ) )
					ship.isMothership = true;
					
			}
		}
		
		ship.mass = totalMass;//linear mass growth
		ship.vel = vel;
		ship.angle_vel = angle_vel;
		if ( ship.centerBlock !is null )
		{
			ship.angle = ship.centerBlock.getAngleDegrees();
			ship.pos = ship.centerBlock.getPosition();
		}
	}
	
	if (ship.centerBlock is null)
	{
		if ( !getNet().isClient() )
			warn("ship.centerBlock is null");
		return;
	}

	center = ship.centerBlock.getPosition();
	//print( ship.id + " mass: " + totalMass + "; effective: " + ship.mass );
	
	//update block positions/angle array
	for (uint b_iter = 0; b_iter < ship.blocks.length; ++b_iter)
	{
		ShipBlock@ ship_block = ship.blocks[b_iter];
		CBlob@ b = getBlobByNetworkID( ship_block.blobID );
		if (b !is null)
		{
			ship_block.offset = b.getPosition() - center;
			ship_block.offset.RotateBy( -ship.angle );
			ship_block.angle_offset = b.getAngleDegrees() - ship.angle;
		}
	}
}

void UpdateShips( CRules@ this, const bool integrate = true, const bool forceOwnerSearch = false )
{
	updatedThisTick = true;
	bool isServer = getNet().isServer();
	CMap@ map = getMap();
	
	Ship[]@ ships;
	this.get( "ships", @ships );	
	for (uint i = 0; i < ships.length; ++i)
	{
		Ship @ship = ships[i];

		ship.soundsPlayed = 0;
		ship.carryMass = 0;
		
		if (!ship.initialized || ship.centerBlock is null)
		{
			if ( !isServer ) print ("client: initializing ship: " + ship.blocks.length);
			InitShip( ship );
			ship.initialized = true;
		}

		if ( integrate )
		{
			ship.old_pos = ship.pos;
			ship.old_angle = ship.angle;
			ship.pos += ship.vel;		
			ship.angle += ship.angle_vel;
			ship.vel *= VEL_DAMPING;
			ship.angle_vel *= ANGLE_VEL_DAMPING;
			
			while(ship.angle < 0.0f)
				ship.angle += 360.0f;
				
			while(ship.angle > 360.0f)
				ship.angle -= 360.0f;
		}

		if ( !isServer || ( !forceOwnerSearch && ( getGameTime() + ship.id * 33 ) % 45 > 0 ) )//updateShipBlobs if !isServer OR isServer and not on a 'second tick'
		{
			for (uint b_iter = 0; b_iter < ship.blocks.length; ++b_iter)
			{
				ShipBlock@ ship_block = ship.blocks[b_iter];
				CBlob@ b = getBlobByNetworkID( ship_block.blobID );
				if ( b !is null )
				{
					UpdateShipBlob( b, ship, ship_block );
				}
			}
		}
		else//(server) updateShipBlobs and find ship.owner once a second or after GenerateShips()
		{
			u8 cores = 0;
			CBlob@ core = null;
			bool multiTeams = false;
			s8 teamComp = -1;	
			u16[] seatIDs;
			
			for (uint b_iter = 0; b_iter < ship.blocks.length; ++b_iter)
			{
				ShipBlock@ ship_block = ship.blocks[b_iter];
				CBlob@ b = getBlobByNetworkID( ship_block.blobID );
				if (b !is null)
				{
					UpdateShipBlob( b, ship, ship_block );
					
					if ( b.hasTag( "control" ) && b.get_string( "playerOwner" ) != "" )
					{
						seatIDs.push_back( ship_block.blobID );
						
						if ( teamComp == -1 )
							teamComp = b.getTeamNum();
						else if ( b.getTeamNum() != teamComp )
							multiTeams = true;
					} 
					else if ( b.hasTag( "mothership" ) )
					{
						cores++;
						@core = b;
					}
				}
			}
			
			string oldestSeatOwner = "";
			
			if ( seatIDs.length > 0 )
			{
				seatIDs.sortAsc();
				if ( ship.isMothership )
				{
					if ( cores > 1 && multiTeams )
						oldestSeatOwner = "*";
					else if ( core !is null )
						for ( int i = 0; i < seatIDs.length; i++ )
						{
							CBlob@ oldestSeat = getBlobByNetworkID( seatIDs[i] );
							if ( oldestSeat !is null && coreLinkedDirectional( oldestSeat, getGameTime(), core.getPosition() ) )
							{
								oldestSeatOwner = oldestSeat.get_string( "playerOwner" );
								break;
							}
						}
				}
				else
				{
					if ( multiTeams )
						oldestSeatOwner = "*";
					else
						for ( int i = 0; i < seatIDs.length; i++ )
						{
							CBlob@ oldestSeat = getBlobByNetworkID( seatIDs[i] );
							if ( oldestSeat !is null )
							{
								oldestSeatOwner = oldestSeat.get_string( "playerOwner" );
								break;
							}
						}
				}
			}
			
			//change ship color (only non-motherships that have activated seats)
			if ( !ship.isMothership && !multiTeams && oldestSeatOwner != "" && ship.owner != oldestSeatOwner )
			{
				CPlayer@ iOwner = getPlayerByUsername( oldestSeatOwner );
				if ( iOwner !is null )
					setShipTeam( ship, iOwner.getTeamNum() );
			}
			
			ship.owner = oldestSeatOwner;
		}
		//if( ship.owner != "") 	print( "updated ship " + ship.id + "; owner: " + ship.owner + "; mass: " + ship.mass );
	}
	
	//calculate carryMass weight
	CBlob@[] humans;
	getBlobsByName( "human", @humans );
	for ( u8 i = 0; i < humans.length; i++ )
	{
	    CBlob@[]@ blocks;
		if ( humans[i].get( "blocks", @blocks ) && blocks.size() > 0 )
		{
			Ship@ ship = getShip( humans[i] );
			if ( ship !is null )
			{
				//player-carried blocks add to the ship mass (with penalty)
				for ( u8 i = 0; i < blocks.length; i++ )
					ship.carryMass += 2.5f * blocks[i].get_f32( "weight" );
			}
		}
	}
}

void UpdateShipBlob( CBlob@ blob, Ship @ship, ShipBlock@ ship_block )
{
	Vec2f offset = ship_block.offset;
	offset.RotateBy( ship.angle );
 	
 	blob.setPosition( ship.pos + offset );
 	blob.setAngleDegrees( ship.angle + ship_block.angle_offset );

	blob.setVelocity( Vec2f_zero );
	blob.setAngularVelocity( 0.0f );
}

void setShipTeam( Ship @ship, u8 teamNum = 255 )
{
	//print (  "setting team for " + ship.owner + "'s " + ship.id + " to " + teamNum );
	for ( uint b_iter = 0; b_iter < ship.blocks.length; ++b_iter )
	{
		CBlob@ b = getBlobByNetworkID( ship.blocks[b_iter].blobID );
		if ( b !is null )
		{
			int blockType = b.getSprite().getFrame();
			b.server_setTeamNum( teamNum );
			b.getSprite().SetFrame( blockType );
		}
	}
}

void onBlobChangeTeam( CRules@ this, CBlob@ blob, const int oldTeam )//awkward fix for blob team changes wiping up the frame state (rest on Block.as)
{
	if ( !getNet().isServer() && blob.getName() == "block" )
		blob.set_u8( "frame", blob.getSprite().getFrame() );
}

void StoreVelocities( CRules@ this )
{
	Ship[]@ ships;
	if (this.get( "ships", @ships ))
		for (uint i = 0; i < ships.length; ++i)
		{
			Ship @ship = ships[i];
					
			for (uint b_iter = 0; b_iter < ship.blocks.length; ++b_iter)
			{
				CBlob@ b = getBlobByNetworkID( ship.blocks[b_iter].blobID );
				if (b !is null)
				{
					b.setVelocity( ship.vel );
					b.setAngularVelocity( ship.angle_vel );	
				}
			}
		}
}

void onBlobDie( CRules@ this, CBlob@ blob )
{
	// this will leave holes until next full sync
	if (blob.getShape().getVars().customData > 0)
	{
		const u16 id = blob.getNetworkID();
		Ship@ ship = getShip( blob.getShape().getVars().customData );
		if (ship !is null)
		{
			for (uint b_iter = 0; b_iter < ship.blocks.length; ++b_iter)
			{
				if (ship.blocks[b_iter].blobID == id){
					ship.blocks.erase(b_iter); 
					if (ship.centerBlock is null || ship.centerBlock.getNetworkID() == id)
					{
						@ship.centerBlock = null;
						ship.initialized = false;
					}
					b_iter = 0;

					//if (blob.getSprite().getFrame() == Block::COUPLING){
					//	this.set_bool("dirty ships", true);		
					//	return;
					//}
				}
			}
			//if (ship.blocks.length == 0)
				this.set_bool("dirty ships", true);			
		}
	}
}

void setUpdateSeatsArrays()
{
	CBlob@[] seats;
	if ( getBlobsByTag( "player", @seats ) )
		for ( uint i = 0; i < seats.length; i++ )
			seats[i].set_bool( "updateArrays", true );
}


// network

void Synchronize( CRules@ this, bool full_sync, CPlayer@ player = null )
{
	CBitStream bs;
	if (Serialize( this, bs, full_sync ))
		this.SendCommand( full_sync ? this.getCommandID("ships sync") : this.getCommandID("ships update"), bs, player );
}

bool Serialize( CRules@ this, CBitStream@ stream, const bool full_sync )
{
	Ship[]@ ships;
	if (this.get( "ships", @ships ))
	{
		stream.write_u16( ships.length );
		bool atLeastOne = false;
		for (uint i = 0; i < ships.length; ++i)
		{
			Ship @ship = ships[i];
			if (full_sync)
			{
				stream.write_Vec2f( ship.pos );
				CPlayer@ owner = getPlayerByUsername( ship.owner );
				stream.write_u16( owner !is null ? owner.getNetworkID() : 0 );
				stream.write_u16( ship.centerBlock !is null ? ship.centerBlock.getNetworkID() : 0 );
				stream.write_Vec2f( ship.vel );
				stream.write_f32( ship.angle );
				stream.write_f32( ship.angle_vel );			
				stream.write_f32( ship.mass );
				stream.write_bool( ship.isMothership );
				stream.write_u16( ship.blocks.length );
				for (uint b_iter = 0; b_iter < ship.blocks.length; ++b_iter)
				{
					ShipBlock@ ship_block = ship.blocks[b_iter];
					CBlob@ b = getBlobByNetworkID( ship_block.blobID );
					if (b !is null)
					{
						stream.write_netid( b.getNetworkID() );	
						stream.write_Vec2f( ship_block.offset );
						stream.write_f32( ship_block.angle_offset );
					}
					else
					{
						stream.write_netid( 0 );	
						stream.write_Vec2f( Vec2f_zero );
						stream.write_f32( 0.0f );
					}
				}
				ship.net_pos = ship.pos;		
				ship.net_vel = ship.vel;
				ship.net_angle = ship.angle;
				ship.net_angle_vel = ship.angle_vel;
				atLeastOne = true;
			}
			else
			{
				const f32 thresh = 0.005f;
				if ((getGameTime()+i) % FORCE_UPDATE_TICKS == 0 || isShipChanged( ship ))				
				{
					stream.write_bool( true );
					CPlayer@ owner = getPlayerByUsername( ship.owner );
					stream.write_u16( owner !is null ? owner.getNetworkID() : 0 );			
					if ((ship.net_pos - ship.pos).LengthSquared() > thresh){
						stream.write_bool( true );
						stream.write_Vec2f( ship.pos );
						ship.net_pos = ship.pos;
					}
					else stream.write_bool( false );

					
					if ((ship.net_vel - ship.vel).LengthSquared() > thresh){
						stream.write_bool( true );
						stream.write_Vec2f( ship.vel );
						ship.net_vel = ship.vel;
					}
					else stream.write_bool( false );
					
					if (Maths::Abs(ship.net_angle - ship.angle) > thresh){
						stream.write_bool( true );
						stream.write_f32( ship.angle );
						ship.net_angle = ship.angle;
					}
					else stream.write_bool( false );

					if (Maths::Abs(ship.net_angle_vel - ship.angle_vel) > thresh){
						stream.write_bool( true );
						stream.write_f32( ship.angle_vel );
						ship.net_angle_vel = ship.angle_vel;
					}
					else stream.write_bool( false );

					atLeastOne = true;		
				}
				else
					stream.write_bool( false );
			}
		}
		return atLeastOne;
	}
	
	warn("ships not found on serialize");
	return false;
}

void onCommand( CRules@ this, u8 cmd, CBitStream @params )
{
	if (getNet().isServer())
		return;

	if (cmd == this.getCommandID("ships sync"))
	{
		Ship[]@ ships;
		if (this.get( "ships", @ships ))
		{
			ships.clear();
			const u16 count = params.read_u16();
			for (uint i = 0; i < count; ++i)
			{
				Ship ship;
				if (!params.saferead_Vec2f(ship.pos)){
					warn("ships sync: ship.pos not found");
					return;
				}
				u16 ownerID = params.read_u16();
				CPlayer@ owner = ownerID != 0 ? getPlayerByNetworkId( ownerID ) : null;
				ship.owner = owner !is null ? owner.getUsername() : "";
				u16 centerBlockID = params.read_u16();
				@ship.centerBlock = centerBlockID != 0 ? getBlobByNetworkID( centerBlockID ) : null;
				ship.vel = params.read_Vec2f();
				ship.angle = params.read_f32();
				ship.angle_vel = params.read_f32();
				ship.mass = params.read_f32();
				ship.isMothership = params.read_bool();
				if ( ship.centerBlock !is null )
				{
					ship.initialized = true;
					if ( ship.vel.LengthSquared() > 0.01f )//try to use local values to smoother sync
					{
						ship.pos = ship.centerBlock.getPosition();
						ship.angle = ship.centerBlock.getAngleDegrees();
					}
				}
				ship.old_pos = ship.pos;
				ship.old_angle = ship.angle;
				
				const u16 blocks_count = params.read_u16();
				for (uint b_iter = 0; b_iter < blocks_count; ++b_iter)
				{
					u16 netid;
					if (!params.saferead_netid(netid)){
						warn("ships sync: netid not found");
						return;
					}
					CBlob@ b = getBlobByNetworkID( netid );
					Vec2f pos = params.read_Vec2f();
					f32 angle = params.read_f32();
					if (b !is null)
					{
						ShipBlock ship_block;
						ship_block.blobID = netid;
						ship_block.offset = pos;
						ship_block.angle_offset = angle;
						ship.blocks.push_back(ship_block);	
	    				b.getShape().getVars().customData = i+1; // color		
							// safety on desync
							b.SetVisible(true);
						    CSprite@ sprite = b.getSprite();
	    					sprite.asLayer().SetColor( color_white );
	    					sprite.asLayer().setRenderStyle( RenderStyle::normal );
					}
					else
						warn(" Blob not found when creating ship, id = " + netid);
				}
				ships.push_back(ship);
			}

			UpdateShips( this, false );
		}
		else
		{
				warn("Ships not found on sync");
				return;
		}
	}
	else if (cmd == this.getCommandID("ships update"))
	{
		Ship[]@ ships;
		if (this.get( "ships", @ships ))
		{
			u16 count;
			if (!params.saferead_u16(count)){
				warn("ships update: count not found");
				return;
			}
			if (count != ships.length){
				warn("Update received before ship sync " + count + " != " + ships.length);
				return;
			}
			for (uint i = 0; i < count; ++i)
			{
				if (params.read_bool())
				{
					Ship @ship = ships[i];
					u16 ownerID = params.read_u16();
					CPlayer@ owner = ownerID != 0 ? getPlayerByNetworkId( ownerID ) : null;
					ship.owner = owner !is null ? owner.getUsername() : "";
					if (params.read_bool())
					{
						Vec2f dDelta = params.read_Vec2f() - ship.pos;
						if ( dDelta.LengthSquared() < 512 )//8 blocks threshold
							ship.pos = ship.pos + dDelta/UPDATE_DELTA_SMOOTHNESS;
						else
							ship.pos += dDelta; 
					}
					if (params.read_bool())
					{
						ship.vel = params.read_Vec2f();
					}
					if (params.read_bool())
					{
						f32 aDelta =  params.read_f32() - ship.angle;
						if ( aDelta > 180 )	aDelta -= 360;
						if ( aDelta < -180 )	aDelta += 360;
						ship.angle = ship.angle + aDelta/UPDATE_DELTA_SMOOTHNESS;
						while ( ship.angle < 0.0f )	ship.angle += 360.0f;
						while ( ship.angle > 360.0f )	ship.angle -= 360.0f;
					}
					if (params.read_bool())
					{
						ship.angle_vel = params.read_f32()/ANGLE_VEL_DAMPING;
					}
				}
			}
			//no need to UpdateShips()
		}
		else
		{
				warn("Ships not found on update");
				return;
		}
	}
}

void onNewPlayerJoin( CRules@ this, CPlayer@ player )
{
	if (!player.isMyPlayer())
		Synchronize( this, true, player ); // will set old values
}

bool isShipChanged( Ship@ ship )
{
	const f32 thresh = 0.01f;
	return ((ship.pos - ship.old_pos).LengthSquared() > thresh || Maths::Abs(ship.angle - ship.old_angle) > thresh);
}

bool candy = false;
bool onClientProcessChat( CRules@ this, const string &in textIn, string &out textOut, CPlayer@ player )
{	
	if (  player !is null )
	{
		bool myPlayer = player.isMyPlayer();
		if ( myPlayer && textIn == "!candy" )
		{
			candy = !candy;
			return false;
		}
		
		if (textIn.substr(0,1) == "!" )
		{
			string[]@ tokens = textIn.split(" ");

			if (tokens[0] == "!ds")
			{
				if ( myPlayer )
				{
					if (tokens.length > 1)
					{
						UPDATE_DELTA_SMOOTHNESS = Maths::Max( 1.0f, parseFloat( tokens[1] ) );
						client_AddToChat( "Delta smoothness set to " + UPDATE_DELTA_SMOOTHNESS );
					} else
						client_AddToChat( "Delta smoothness: " + UPDATE_DELTA_SMOOTHNESS );
				}
				return false;
			}
		}
	}
	
	return true;
}

void onRender( CRules@ this )
{
	if (g_debug == 1 || candy)
	{
		CCamera@ camera = getCamera();
		if ( camera is null ) return;
		f32 camRotation = camera.getRotation();
		Ship[]@ ships;
		if (this.get( "ships", @ships ))
			for (uint i = 0; i < ships.length; ++i)
			{
				Ship @ship = ships[i];
				if ( ship.centerBlock !is null )
				{
					Vec2f cbPos = getDriver().getScreenPosFromWorldPos( ship.centerBlock.getPosition() );
					Vec2f iVel = ship.vel * 20;
					iVel.RotateBy( -camRotation );					
					GUI::DrawArrow2D( cbPos, cbPos + iVel, SColor( 175, 0, 200, 0) );
					//GUI::DrawText( "" + ship.vel.Length(), cbPos, SColor( 255,255,255,255 ));
				}
					
				for (uint b_iter = 0; b_iter < ship.blocks.length; ++b_iter)
				{
					ShipBlock@ ship_block = ship.blocks[b_iter];
					CBlob@ b = getBlobByNetworkID( ship_block.blobID );
					if (b !is null)
					{
						int c = b.getShape().getVars().customData;
						GUI::DrawRectangle( getDriver().getScreenPosFromWorldPos(b.getPosition() - Vec2f(4, 4).RotateBy( camRotation ) )
						, getDriver().getScreenPosFromWorldPos(b.getPosition() + Vec2f(4, 4).RotateBy( camRotation ) ), SColor( 100, c*50, -c*90, 93*c ) );
						GUI::DrawText( "" + ship_block.blobID, getDriver().getScreenPosFromWorldPos(b.getPosition()), SColor( 255,255,255,255 ));
					}
				}
			}
	}
}
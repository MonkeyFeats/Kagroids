
#include "BlockCommon.as"
#include "ThrusterForceCommon.as"

const u16 UNUSED_RESET = 2 * 60 * 30;
const u8 CANNON_FIRE_CYCLE = 15;

void onInit( CBlob@ this )
{
	this.Tag("player");	
	this.Tag("mothership");
	AddIconToken( "$SOLID$", "Blocks.png", Vec2f(8,8), 4 );
	//Set Owner/couplingsCooldown
	if ( getNet().isServer() )
	{
		u16[] left_propellers, strafe_left_propellers, strafe_right_propellers, right_propellers, up_propellers, down_propellers, machineguns, cannons;					
		this.set( "left_propellers", left_propellers );
		this.set( "strafe_left_propellers", strafe_left_propellers );
		this.set( "strafe_right_propellers", strafe_right_propellers );
		this.set( "right_propellers", right_propellers );
		this.set( "up_propellers", up_propellers );
		this.set( "down_propellers", down_propellers );
		this.set( "machineguns", machineguns );
		this.set( "cannons", cannons );
		
		this.set_bool( "kUD", false );
		this.set_bool( "kLR", false );
		this.set_u32( "lastCannonFire", getGameTime() );
		this.set_u8( "cannonFireIndex", 0 );
		this.set_u32( "lastActive", getGameTime() );
		this.set_u32( "lastOwnerUpdate", 0 );

	}

	this.Tag("control");
	
	//anim
	CSprite@ sprite = this.getSprite();
    if(sprite !is null)
    {
        //default
        {
            Animation@ anim = sprite.addAnimation("default", 0, false);
            anim.AddFrame(Block::COMMAND_MODULE);
        }
    }
}

Vec2f[] Trajectory;
void CalculateTrajectory(Ship@ ship)
{ 
	Vec2f PlanetCenter(11*128, 11*128);
	Vec2f pos = ship.pos;
	Vec2f vel = ship.vel;
	float speed = vel.Length();	

	float timestep = 3.0+(speed/3.0);
	const int PlotMaxSteps = 256;

	const float Gravity = -9.81;
	const double PlanetMass = 597.2;
	const double ShipMass = ship.mass;

	Trajectory.set_length(PlotMaxSteps);
	Trajectory[0] = pos;


    for ( int i = 1; i < PlotMaxSteps; ++i )
    { 
    	//distance from earths center to the surface = 6360km
		//satalittes orbit earth between 6666 km - 35500 km, 17700km is good for GPS&
		double orbitDistance = Maths::Max((PlanetCenter-pos).Length()*8, 1);
		
		// Gravity*((Mass1*Mass2)/DistanceToMassCenter)
		double gravforce = (Gravity*PlanetMass*ShipMass)/orbitDistance;
		//print("gravforce "+gravforce);

		Vec2f GravityVec(gravforce, 0 );

		double ShipAngleToPlanet = (pos-PlanetCenter).Angle();
		GravityVec.RotateByDegrees(-ShipAngleToPlanet);

        vel += GravityVec/600;
        pos += vel;

	    Trajectory[i] = pos;
    }	
}

void onRender(CSprite@ this)
{
	CMap@ map = this.getBlob().getMap();

	//line to center
	//GUI::DrawLine2D(getDriver().getScreenPosFromWorldPos(pos), getDriver().getScreenPosFromWorldPos(PlanetCenter), color_white);


	for (uint i = 1; i < Trajectory.length(); i++)
	{
		GUI::DrawLine2D(getDriver().getScreenPosFromWorldPos(Trajectory[i-1]), getDriver().getScreenPosFromWorldPos(Trajectory[i]), SColor(255,255,0,i*25));
	}
	//GUI::DrawLine(pos, pos+PlanetaryInetia, SColor(255,255,0,0));

	//GUI::DrawSpline(pos, PlanetCenter/2+pos, pos+PlanetaryInetia, pos, 16, SColor(255,255,0,0));
	//GUI::DrawCircle(getDriver().getScreenPosFromWorldPos(PlanetCenter), (PlanetCenter-(pos+PlanetaryInetia*30)).Length(), SColor(255,255,0,0));


		//print("angle "+ShipAngleToPlanet);

}

void onTick( CBlob@ this )
{
	if (this.getShape().getVars().customData <= 0) return;	
	bool isServer = getNet().isServer();
	u32 gameTime = getGameTime();
	u8 teamNum = this.getTeamNum();
	
	CSprite@ sprite = this.getSprite();

	
	Ship@ ship = getShip(this.getShape().getVars().customData);
	if ( ship is null )	return;

	if (getGameTime() % 180 == 0)
		CalculateTrajectory(ship);
	
	//if ( occupier !is null )
	{				
		CPlayer@ player = this.getPlayer();
		if ( player is null )	return;


		CRules@ rules = getRules();
		CHUD@ HUD = getHUD();
		string occupierName = player.getUsername();
		u8 occupierTeam = this.getTeamNum();
			
		const bool up = this.isKeyPressed( key_up );
		const bool left = this.isKeyPressed( key_left );
		const bool right = this.isKeyPressed( key_right );
		const bool down = this.isKeyPressed( key_down );
		const bool space = this.isKeyPressed( key_action3 );	
		const bool inv = this.isKeyPressed( key_inventory );
		const bool strafe = this.isKeyPressed( key_pickup ) || this.isKeyPressed( key_taunts );
		const bool left_click = this.isKeyPressed( key_action1 );	
		const bool right_click = this.isKeyPressed( key_action2 );	

		//client-side couplings managing functions
		if ( player.isMyPlayer() )
		{
			//gather couplings and flak
			CBlob@[] couplings, flak;
			for (uint b_iter = 0; b_iter < ship.blocks.length; ++b_iter)
			{
				ShipBlock@ ship_block = ship.blocks[b_iter];
				if(ship_block is null) continue;

				CBlob@ block = getBlobByNetworkID( ship_block.blobID );
				if(block is null) continue;
				
				//gather couplings
				if (block.hasTag("coupling") && !block.hasTag("_coupling_hitspace"))
					couplings.push_back(block);
				else if ( block.hasTag( "flak" ) )
					flak.push_back(block);
			}
						
						
			//hax: update can't-decouplers
			if ( space )
			{
				for (uint i = 0; i < couplings.length; ++i)
				{
					CBlob@ c = couplings[i];
						this.ClickClosestInteractButton( c.getPosition(), 0.0f );
						
						CButton@ button = this.CreateGenericButton( 1, Vec2f_zero, c, c.getCommandID("decouple"), "Decouple (crew's)" );
						if ( button !is null )	button.enableRadius = 999.0f;
				}
			}

			//Kill coupling/turret buttons on spacebar up
			if ( this.isKeyJustReleased( key_action3 ) )
				this.ClearButtons();
		
			//Release all couplings on spacebar + right click
			if ( space && HUD.hasButtons() && right_click )
				for ( uint i = 0; i < couplings.length; ++i )
					if ( couplings[i].get_string( "playerOwner" ) == occupierName )
					{
						couplings[i].Tag("_coupling_hitspace");
						couplings[i].SendCommand(couplings[i].getCommandID("decouple"));
					}
				
		}
		
		//******svOnly below
		if ( !isServer )
			return;

		//update if ships changed
		if ( this.get_bool( "updateArrays" ) && ( gameTime + this.getNetworkID() ) % 10 == 0 )
			updateArrays( this, ship );
		
		
			// gather propellers, couplings, machineguns and cannons
			u16[] left_propellers, strafe_left_propellers, strafe_right_propellers, right_propellers, up_propellers, down_propellers, machineguns, cannons;					
			this.get( "left_propellers", left_propellers );
			this.get( "strafe_left_propellers", strafe_left_propellers );
			this.get( "strafe_right_propellers", strafe_right_propellers );
			this.get( "right_propellers", right_propellers );
			this.get( "up_propellers", up_propellers );
			this.get( "down_propellers", down_propellers );
			this.get( "machineguns", machineguns );
			this.get( "cannons", cannons );

			//reset			
			if ( this.get_bool( "kUD" ) && !up && !down  )
			{
				this.set_bool( "kUD", false );
	
				for (uint i = 0; i < up_propellers.length; ++i)
				{
					CBlob@ prop = getBlobByNetworkID( up_propellers[i] );
					if ( prop !is null )
						prop.set_f32("power", 0);
				}
				
				for (uint i = 0; i < down_propellers.length; ++i)
				{
					CBlob@ prop = getBlobByNetworkID( down_propellers[i] );
					if ( prop !is null )
						prop.set_f32("power", 0);
				}
			}
			if ( this.get_bool( "kLR" ) && ( strafe || ( !left && !right ) ) )
			{
				this.set_bool( "kLR", false );

				for (uint i = 0; i < left_propellers.length; ++i)
				{
					CBlob@ prop = getBlobByNetworkID( left_propellers[i] );
					if ( prop !is null )
						prop.set_f32("power", 0);
				}
				
				for (uint i = 0; i < right_propellers.length; ++i)
				{
					CBlob@ prop = getBlobByNetworkID( right_propellers[i] );
					if ( prop !is null )
						prop.set_f32("power", 0);
				}
			}
			
			//power to use
			f32 power, reverse_power;
			if ( ship.isMothership )
			{
				power = -1.05f;
				reverse_power = 0.15f;
			} else
			{
				power = -1.0f;
				reverse_power = 0.1f;
			}
			
			//movement modes
			if ( up || down )
			{

				this.set_bool( "kUD", true );

				for (uint i = 0; i < up_propellers.length; ++i)
				{					
					CBlob@ prop = getBlobByNetworkID( up_propellers[i] );
					if ( prop !is null )
					{
						prop.set_u32( "onTime", gameTime );
						prop.set_f32("power", up ? power * prop.get_f32("powerFactor") : reverse_power * prop.get_f32("powerFactor"));
					}
				}
				for (uint i = 0; i < down_propellers.length; ++i)
				{
					CBlob@ prop = getBlobByNetworkID( down_propellers[i] );
					if ( prop !is null )
					{
						prop.set_u32( "onTime", gameTime );
						prop.set_f32("power", down ? power * prop.get_f32("powerFactor") : reverse_power * prop.get_f32("powerFactor"));
					}
				}
			}
			
			if ( left || right )
			{
				this.set_bool( "kLR", true );

				if ( !strafe )
				{
					for (uint i = 0; i < left_propellers.length; ++i)
					{
						CBlob@ prop = getBlobByNetworkID( left_propellers[i] );
						if ( prop !is null)
						{
							prop.set_u32( "onTime", gameTime );
							prop.set_f32("power", left ? power * prop.get_f32("powerFactor") : reverse_power * prop.get_f32("powerFactor"));
						}
					}
					for (uint i = 0; i < right_propellers.length; ++i)
					{
						CBlob@ prop = getBlobByNetworkID( right_propellers[i] );
						if ( prop !is null )
						{
							prop.set_u32( "onTime", gameTime );
							prop.set_f32("power", right ? power * prop.get_f32("powerFactor") : reverse_power * prop.get_f32("powerFactor"));
						}
					}
				} else
				{
					u8 maxStrafers = Maths::Round( Maths::FastSqrt( ship.mass )/3.0f );
					for (uint i = 0; i < strafe_left_propellers.length; ++i)
					{
						CBlob@ prop = getBlobByNetworkID( strafe_left_propellers[i] );
						f32 oDrive = i < maxStrafers ? 2.0f : 1.0f;
						if ( prop !is null )
						{
							prop.set_u32( "onTime", gameTime );
							prop.set_f32("power", left ? oDrive * power * prop.get_f32("powerFactor") : reverse_power * prop.get_f32("powerFactor"));
						}
					}
					for (uint i = 0; i < strafe_right_propellers.length; ++i)
					{
						CBlob@ prop = getBlobByNetworkID( strafe_right_propellers[i] );
						f32 oDrive = i < maxStrafers ? 2.0f : 1.0f;
						if ( prop !is null )
						{
							prop.set_u32( "onTime", gameTime );
							prop.set_f32("power", right ? oDrive * power * prop.get_f32("powerFactor") : reverse_power * prop.get_f32("powerFactor"));
						}
					}
				}
			}
	}
}


void updateArrays( CBlob@ this, Ship@ ship )
{
	this.set_bool( "updateArrays", false );


	u16[] left_propellers, strafe_left_propellers, strafe_right_propellers, right_propellers, up_propellers, down_propellers, machineguns, cannons;					
	for (uint b_iter = 0; b_iter < ship.blocks.length; ++b_iter)
	{
		ShipBlock@ ship_block = ship.blocks[b_iter];
		if(ship_block is null) continue;

		CBlob@ block = getBlobByNetworkID( ship_block.blobID );
		if(block is null) continue;
					
		//machineguns
		if (block.hasTag("machinegun"))
			machineguns.push_back(block.getNetworkID());
		
		if (block.hasTag("cannon"))
			cannons.push_back(block.getNetworkID());
		
		//propellers
		if ( block.hasTag("thruster") )
		{
			Vec2f _veltemp, velNorm;
			float angleVel;
			ThrusterForces(block, ship, 1.0f, _veltemp, velNorm, angleVel);

			velNorm.RotateBy(-this.getAngleDegrees());
			
			const float angleLimit = 0.05f;
			const float forceLimit = 0.01f;
			const float forceLimit_side = 0.2f;

			if ( angleVel < -angleLimit || ( velNorm.y < -forceLimit_side && angleVel < angleLimit ) )
				right_propellers.push_back(block.getNetworkID());
			else if ( angleVel > angleLimit || ( velNorm.y > forceLimit_side && angleVel > -angleLimit ) )
				left_propellers.push_back(block.getNetworkID());
			
			if ( Maths::Abs( velNorm.x ) < forceLimit )
			{
				if ( velNorm.y < -forceLimit_side )
					strafe_right_propellers.push_back(block.getNetworkID());
				else if ( velNorm.y > forceLimit_side )
					strafe_left_propellers.push_back(block.getNetworkID());
			}

			if ( velNorm.x > forceLimit )
				down_propellers.push_back(block.getNetworkID());
			else if ( velNorm.x < -forceLimit )
				up_propellers.push_back(block.getNetworkID());
		}
	}
	
	cannons.sortAsc();
	
	this.set( "left_propellers", left_propellers );
	this.set( "strafe_left_propellers", strafe_left_propellers );
	this.set( "strafe_right_propellers", strafe_right_propellers );
	this.set( "right_propellers", right_propellers );
	this.set( "up_propellers", up_propellers );
	this.set( "down_propellers", down_propellers );
	this.set( "machineguns", machineguns );
	this.set( "cannons", cannons );
}

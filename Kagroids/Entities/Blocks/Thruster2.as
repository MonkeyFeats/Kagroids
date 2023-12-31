#include "ShipsCommon.as"
#include "BlockCommon.as"
//#include "WaterEffects.as"
#include "ThrusterForceCommon.as"
#include "AccurateSoundPlay.as"
#include "TileCommon.as"

Random _r(133701); //global clientside random object

void onInit( CBlob@ this )
{
	this.addCommandID("on/off");
	this.addCommandID("off");
	this.Tag("thruster");
	this.set_f32("power", 0.0f);
	this.set_f32("powerFactor", 2.0f);
	this.set_u32( "onTime", 0 );

	CSprite@ sprite = this.getSprite();

    sprite.SetEmitSound("PropellorMotor");
    sprite.SetEmitSoundPaused(true);
}

void onCommand( CBlob@ this, u8 cmd, CBitStream @params )
{
    if (cmd == this.getCommandID("on/off") && getNet().isServer())
    {
		this.set_f32("power", isOn(this) ? 0.0f : -this.get_f32("powerFactor"));
    }
	
    if (cmd == this.getCommandID("off") && getNet().isServer())
    {
		this.set_f32("power", 0.0f);
    }
	
}

bool isOn(CBlob@ this)
{
	return this.get_f32("power") != 0;
}

void onTick( CBlob@ this )
{
	if (this.getShape().getVars().customData <= 0)
		return;
	
	u32 gameTime = getGameTime();
	CSprite@ sprite = this.getSprite();
	f32 power = this.get_f32("power");
	Vec2f pos = this.getPosition();
	const bool on = power != 0;	
	
	if ( getNet().isServer() )
		this.Sync("power", true);

	if (on)
	{
		//auto turn off after a while
		if ( getNet().isServer() && gameTime - this.get_u32( "onTime") > 750 )
		{
			this.SendCommand( this.getCommandID( "off" ) );
			return;
		}
			
		Ship@ ship = getShip(this.getShape().getVars().customData);
		if (ship !is null)
		{
			// move
			Vec2f moveVel;
			Vec2f moveNorm;
			float angleVel;
			
			ThrusterForces(this, ship, power, moveVel, moveNorm, angleVel);
			
			const f32 mass = ship.mass + ship.carryMass;
			moveVel /= mass;
			angleVel /= mass;
			
			ship.vel += moveVel;
			ship.angle_vel += angleVel;
		
			// eat stuff
			if (getNet().isServer() && ( gameTime + this.getNetworkID() ) % 15 == 0)
			{
				//eat stuff
				Vec2f faceNorm(0,-1);
				faceNorm.RotateBy(this.getAngleDegrees());
				CBlob@ victim = getMap().getBlobAtPosition( pos - faceNorm * Block::size );
				if ( victim !is null && !victim.isAttached() 
					 && victim.getShape().getVars().customData > 0
					       && !victim.hasTag( "player" ) )	
				{
					f32 hitPower = Maths::Max( 0.5f, Maths::Abs( this.get_f32("power") ) );
					if ( !victim.hasTag( "mothership" ) )
						this.server_Hit( victim, pos, Vec2f_zero, hitPower, 9, true );
					else
						victim.server_Hit( this, pos, Vec2f_zero, hitPower, 9, true );
				}
			}
			
			// effects
			if ( getNet().isClient() )
			{
				u8 tickStep = v_fastrender ? 20 : 4;
				//if ( ( gameTime + this.getNetworkID() ) % tickStep == 0 && Maths::Abs(power) >= 1 && !isTouchingLand(pos) )
				//{
				//	Vec2f rpos = Vec2f(_r.NextFloat() * -4 + 4, _r.NextFloat() * -4 + 4);
				//	MakeWaterParticle(pos + moveNorm * -6 + rpos, moveNorm * (-0.8f + _r.NextFloat() * -0.3f));
				//}
				
				// limit sounds		
				if (ship.soundsPlayed == 0 && sprite.getEmitSoundPaused() == true)
				{
					sprite.SetEmitSoundPaused(false);								
				}
				ship.soundsPlayed++;
				const f32 vol = Maths::Min(0.5f + float(ship.soundsPlayed)/2.0f, 3.0f);
				sprite.SetEmitSoundVolume( vol );
			}
		}
	}
	else
	{
		if ( sprite.getEmitSoundPaused() == false )
		{
			sprite.SetEmitSoundPaused(true);
		}
	}
}

f32 onHit( CBlob@ this, Vec2f worldPoint, Vec2f velocity, f32 damage, CBlob@ hitterBlob, u8 customData )
{
	return damage;
}

void onHitBlob( CBlob@ this, Vec2f worldPoint, Vec2f velocity, f32 damage, CBlob@ hitBlob, u8 customData )
{
	if ( customData == 9 )
		directionalSoundPlay( "propellerHit.ogg", worldPoint );		
}

Random _smokerandom(0x15125); //clientside
void smoke( Vec2f pos )
{
	CParticle@ p = ParticleAnimated( "SmallSmoke1.png",
											  pos, Vec2f_zero,
											  _smokerandom.NextFloat() * 360.0f, //angle
											  1.0f, //scale
											  3+_smokerandom.NextRanged(2), //animtime
											  0.0f, //gravity
											  true ); //selflit
	if(p !is null)
		p.Z = 110.0f;
}
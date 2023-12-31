#include "ShipsCommon.as"
#include "BlockCommon.as"
#include "MakeDustParticle.as"
#include "AccurateSoundPlay.as"

u8 DAMAGE_FRAMES = 3;
// onInit: called from engine after blob is created with server_CreateBlob()

void onInit( CBlob@ this )
{
	CSprite @sprite = this.getSprite();
	CShape @shape = this.getShape();
	sprite.asLayer().SetLighting( false );
	sprite.SetZ(510.0f);
	shape.getConsts().net_threshold_multiplier = -1.0f;
	this.SetMapEdgeFlags( u8(CBlob::map_collide_none) | u8(CBlob::map_collide_nodeath) );
	this.getShape().SetGravityScale(0.0f);

}

void onTick ( CBlob@ this )
{
	CSprite@ thisSprite = this.getSprite();
	
	if (this.getTickSinceCreated() < 1) //accounts for time after block production
	{
		CRules@ rules = getRules();
		const int blockType = thisSprite.getFrame();
		
		//u16 cost = Block::getCost( blockType );	
		this.set_u32("cost", 1);
		
		this.set_f32("initial reclaim", this.getHealth());
			this.set_f32("current reclaim", this.getHealth());
		
		//Set Owner
		if ( getNet().isServer() )
		{
			CBlob@ owner = getBlobByNetworkID( this.get_u16( "ownerID" ) );    
			if ( owner !is null )
			{
				this.set_string( "playerOwner", owner.getPlayer().getUsername() );
				this.Sync( "playerOwner", true );
			}
		}
	}
	
 	// push merged ships away from each other
	if ( this.get_bool( "colliding" ) == true )
		this.set_bool( "colliding", false ); 

	if ( !getNet().isServer() )	//awkward fix for blob team changes wiping up the frame state (rest on ships.as)
	{
		u8 frame = this.get_u8( "frame" );
		if ( thisSprite.getFrame() == 0 && frame != 0 )
			thisSprite.SetFrame( frame );
	}
}

// onCollision: called once from the engine when a collision happens; 
// blob is null when it is a tilemap collision

void onCollision( CBlob@ this, CBlob@ blob, bool solid, Vec2f normal, Vec2f point1 )
{
	
}

void Die( CBlob@ this )
{
	if(!getNet().isServer()) return;
	
	this.Tag( "noCollide" );
	this.server_Die();
}

void onGib(CSprite@ this)
{
	Vec2f pos = this.getBlob().getPosition();
	MakeDustParticle( pos, "/DustSmall.png");
	directionalSoundPlay( "destroy_wood", pos );
}
// network

void onSendCreateData( CBlob@ this, CBitStream@ stream )
{
	stream.write_u8( Block::getType(this) );
	stream.write_netid( this.get_u16("ownerID") );
}

bool onReceiveCreateData( CBlob@ this, CBitStream@ stream )
{
	u8 type = 0;
	u16 ownerID = 0;

	if (!stream.saferead_u8(type)){
		warn("Block::onReceiveCreateData - missing type");
		return false;	
	}
	if (!stream.saferead_u16(ownerID)){
		warn("Block::onReceiveCreateData - missing ownerID");
		return false;	
	}

	this.getSprite().SetFrame( type );

	CBlob@ owner = getBlobByNetworkID(ownerID);
	if (owner !is null)
	{
	    owner.push( "blocks", @this );
		this.getShape().getVars().customData = -1; // don't push on ship
	}

	return true;
}
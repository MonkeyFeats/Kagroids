
#include "BlockCommon.as"

void MakeBlock( Block::Type type, Vec2f offset, Vec2f pos, CBlob@[]@ list, const uint team )
{
	CBlob@ b = makeBlock( pos + offset*Block::size, 0.0f, type, team );
	list.push_back(b);
	b.set_Vec2f("offset", b.getPosition());
}


CBlob@ makeBlock( Vec2f pos, f32 angle, u16 blockType, const int team = -1 )
{
	CBlob@ block = server_CreateBlob( "block", team, pos );
	if (block !is null) 
	{
		block.getSprite().SetFrame( blockType );
		block.set_f32( "weight", Block::getWeight( block ) );
		block.setAngleDegrees( angle );
		
		switch(blockType)		
		{
			case Block::THRUSTER1:
			block.AddScript("Thruster1.as");
			break;
			case Block::THRUSTER2:
			block.AddScript("Thruster2.as");
			break;	
			case Block::COMMAND_MODULE:
			block.AddScript("CommandModule.as");
			block.getSprite().AddScript("CommandModule.as");
			block.AddScript("Commander.as");
			block.AddScript("PlaceBlocks.as");
			block.AddScript("Camera.as");

			break;	
		}
		
		block.getShape().getVars().customData = 0;
		block.set_u32( "placedTime", getGameTime() );
	}
	return block;
}


void ProduceBlock( CRules@ this, CBlob@ blob, Block::Type type, u8 ammount = 1 )
{
	const int blobTeam = blob.getTeamNum();

	if (getNet().isServer())
	{
		CBlob@[] blocks;
		for ( int i = 0; i < ammount; i++ )
		{
			MakeBlock( type, Vec2f( i, 0 ), Vec2f_zero, @blocks, blobTeam );
		}

    	CBlob@[]@ blob_blocks;
	    blob.get( "blocks", @blob_blocks );
    	blob_blocks.clear();
		u16 blobID = blob.getNetworkID();
		u16 playerID = blob.getPlayer().getNetworkID();
    	for (uint i = 0; i < blocks.length; i++){
    		CBlob@ b = blocks[i];
        	blob_blocks.push_back( b );	        
        	b.set_u16( "ownerID", blobID );
        	b.set_u16( "playerID", playerID );
    		b.getShape().getVars().customData = -1; // don't push on ship
    	}
	}
}
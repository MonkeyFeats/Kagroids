

namespace Commander
{
	bool isHoldingBlocks( CBlob@ this )
	{
	   	CBlob@[]@ blob_blocks;
	    this.get( "blocks", @blob_blocks );
	    return false;
	}
	
	bool wasHoldingBlocks( CBlob@ this )
	{
		return getGameTime() - this.get_u32( "placedTime" ) < 10;
	}
	
	void clearHeldBlocks( CBlob@ this )
	{
		CBlob@[]@ blocks;
		if (this.get( "blocks", @blocks ))                 
		{
			for (uint i = 0; i < blocks.length; ++i)
			{
				blocks[i].Tag( "disabled" );
				blocks[i].server_Die();
			}

			blocks.clear();
		}
	}
}


void BuildShopMenu( CBlob@ this,  string description, Vec2f offset )
{
	CRules@ rules = getRules();
	Block::Costs@ c = Block::getCosts( rules );
	Block::Weights@ w = Block::getWeights( rules );
	
	if ( c is null || w is null )
		return;
		
	CGridMenu@ menu = CreateGridMenu( this.getScreenPos() + offset, this, BUILD_MENU_SIZE, description );
	u32 gameTime = getGameTime();
	string repBuyTip = "\nPress the inventory key to buy again.\n";
	u16 WARMUP_TIME = getPlayersCount() > 1 && !rules.get_bool("freebuild") ? rules.get_u16( "warmup_time" ) : 0;
	string warmupText = "Weapons are enabled after the warm-up time ends.\n";
	
	if ( menu !is null ) 
	{
		menu.deleteAfterClick = true;
		
		u16 netID = this.getNetworkID();
		string lastBuy = this.get_string( "last buy" );
		
		{
			CBitStream params;
			params.write_u16( netID );
			params.write_string( "solid" );
				
			CGridButton@ button = menu.AddButton( "$SOLID$", "Wooden Hull $" + c.solid, this.getCommandID("buyBlock"), params );
	
			bool select = lastBuy == "solid";
			if ( select )
				button.SetSelected(2);
				
			button.SetHoverText( "A very tough block for protecting delicate components. Can effectively negate damage from bullets, flak, and to some extent cannons. \nWeight: " + w.solid * 100 + "rkt\n" + ( select ? repBuyTip : "" ) );
		}
	}
}


void BuyBlock( CBlob@ this, CBlob@ caller, string btype )
{
	CRules@ rules = getRules();
	Block::Costs@ c = Block::getCosts( rules );
	
	if ( c is null )
	{
		warn( "** Couldn't get Costs!" );
		return;
	}

	u8 teamNum = this.getTeamNum();
	u32 gameTime = getGameTime();
	CPlayer@ player = caller.getPlayer();
	string pName = player !is null ? player.getUsername() : "";
	int pBooty = player.getCoins();
	bool weapon = btype == "cannon" || btype == "machinegun" || btype == "flak" || btype == "pointDefense" || btype == "launcher" || btype == "bomb";
	
	u16 cost = -1;
	u8 ammount = 1;
	u8 totalFlaks = 0;
	u8 teamFlaks = 0;
	
	bool coolDown = false;

	Block::Type type;
	if ( btype == "wood" )
	{
		type = Block::A_HULL;
		cost = c.wood;
	}
	else if ( btype == "solid" )
	{
		type = Block::B_HULL;
		cost = c.solid;
	}

	player.server_setCoins( pBooty - cost );
	ProduceBlock( getRules(), caller, type, ammount );
}

void ReturnBlocks( CBlob@ this, CBlob@ caller )
{
	CRules@ rules = getRules();
	CBlob@[]@ blocks;
	if (caller.get( "blocks", @blocks ) && blocks.size() > 0)                 
	{
		if ( getNet().isServer() )
		{
			CPlayer@ player = caller.getPlayer();
			if ( player !is null )
			{
				string pName = player.getUsername();
				u16 pBooty = player.getCoins();
				u16 returnBooty = 0;
				for (uint i = 0; i < blocks.length; ++i)
				{
					int type = Block::getType( blocks[i] );
					if ( type != Block::COUPLING && blocks[i].getShape().getVars().customData == -1 )
						returnBooty += Block::getCost( type );
				}
				
				if ( returnBooty > 0 && !(getPlayersCount() == 1 || rules.get_bool("freebuild")))
					player.server_setCoins( pBooty + returnBooty );
			}
		}
		
		this.getSprite().PlaySound("join.ogg");
		Commander::clearHeldBlocks( caller );
		caller.set_bool( "blockPlacementWarn", false );
	} else
		warn("returnBlocks cmd: no blocks");
}
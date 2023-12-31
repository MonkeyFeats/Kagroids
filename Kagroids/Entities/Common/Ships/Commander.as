#include "CommanderCommon.as"
#include "EmotesCommon.as"
#include "BlockProduction.as"
#include "ShipsCommon.as"
#include "BlockCommon.as"
#include "AccurateSoundPlay.as"
//#include "WaterEffects.as"

int useClickTime = 0;
const int FIRE_RATE = 40;
const u8 BUILD_MENU_COOLDOWN = 30;
const Vec2f BUILD_MENU_SIZE = Vec2f( 6, 3 );
const Vec2f TOOLS_MENU_SIZE = Vec2f( 1, 3 );

void onInit( CBlob@ this )
{
	this.Tag("player");	 
	this.Tag("mothership");	

	this.addCommandID("shoot");
	this.addCommandID("giveBooty");	
	this.addCommandID("buyBlock");
	this.addCommandID("returnBlocks");

	if ( getNet().isClient() )
	{
		this.set_u16( "shipID", this.getNetworkID() );
	}
		
	this.set_u32("menu time", 0);
	this.set_bool( "build menu open", false );
	this.set_string("last buy", "coupling");
	this.set_u32("fire time", 0);
	this.set_f32("cam rotation", 0.0f);

	this.getShape().getVars().onground = true;
	directionalSoundPlay( "Respawn", this.getPosition(), 2.5f );
}

void onTick( CBlob@ this ) { if ( this.isMyPlayer() ) PlayerControls( this ); }

void PlayerControls( CBlob@ this )
{
	CHUD@ hud = getHUD();
	CControls@ controls = getControls();
	bool toolsKey = controls.isKeyJustPressed( controls.getActionKeyKey( AK_PARTY ) );
	CSprite@ sprite = this.getSprite();
	
	// bubble menu
	if (this.isKeyJustPressed(key_bubbles))
	{
		this.CreateBubbleMenu();
	}
	// use menu
    if (this.isKeyJustPressed(key_use))
    {
        useClickTime = getGameTime();
    }
    if (this.isKeyPressed(key_use))
    {
        this.ClearMenus();
		this.ClearButtons();
        this.ShowInteractButtons();
    }
    else if (this.isKeyJustReleased(key_use))
    {
    	bool tapped = (getGameTime() - useClickTime) < 10; 
		this.ClickClosestInteractButton( tapped ? this.getPosition() : this.getAimPos(), this.getRadius()*2 );

        this.ClearButtons();
    }

    // default cursor
	if ( hud.hasMenus() )
		hud.SetDefaultCursor();
	else
	{
		hud.SetCursorImage("PointerCursor.png", Vec2f(32,32));
		hud.SetCursorOffset( Vec2f(-32, -32) );		
	}

	// click action1 to click buttons
	if (hud.hasButtons() && this.isKeyPressed(key_action1) && !this.ClickClosestInteractButton( this.getAimPos(), 2.0f ))
	{
	}

	// click grid menus

    if (hud.hasButtons())
    {
        if (this.isKeyJustPressed(key_action1))
        {
		    CGridMenu @gmenu;
		    CGridButton @gbutton;
		    this.ClickGridMenu(0, gmenu, gbutton); 
	    } else if ( this.isKeyJustPressed(key_inventory) )
		{
			
		}
	}
	
	//build menu
	if (  this.isKeyJustPressed(key_inventory)  )
	{
		if ( !this.hasTag( "critical" ) )
		{
			Ship@ pIsle = getShip( this );
			bool canShop = true;
									
			if ( !Commander::isHoldingBlocks(this) )
			{
				if ( !hud.hasButtons() )
				{
					if ( canShop )
					{
						this.set_bool( "build menu open", true );
					
						CBitStream params;
						params.write_u16( this.getNetworkID() );
						u32 gameTime = getGameTime();
						
						if ( gameTime - this.get_u32( "menu time" ) > BUILD_MENU_COOLDOWN )
						{
							Sound::Play( "buttonclick.ogg" );
							this.set_u32( "menu time", gameTime );
							BuildShopMenu( this, "mCore Block Transmitter", Vec2f(0,0) );
						}
						else
							Sound::Play( "/Sounds/bone_fall1.ogg" );
					}
					else
						Sound::Play( "/Sounds/bone_fall1.ogg" );
				} 
				else if ( hud.hasMenus() )
				{
					this.ClearMenus();
					Sound::Play( "buttonclick.ogg" );
					
					if ( this.get_bool( "build menu open" ) )
					{
						CBitStream params;
						params.write_u16( this.getNetworkID() );
						params.write_string( this.get_string( "last buy" ) );
						
						this.SendCommand( this.getCommandID("buyBlock"), params );

					}
					this.set_bool( "build menu open", false );
				}
			}
			else if ( canShop )
			{
				CBitStream params;
				params.write_u16( this.getNetworkID() );
				this.SendCommand( this.getCommandID("returnBlocks"), params );
			}
		}
	}
}


void onCommand( CBlob@ this, u8 cmd, CBitStream @params )
{
    if (cmd == this.getCommandID("buyBlock"))
    {
    	CBlob@ caller = getBlobByNetworkID( params.read_u16() );
		if ( caller is null )
			return;
			
		string block = params.read_string();
		caller.set_string( "last buy", block );

		if ( !getNet().isServer() || Commander::isHoldingBlocks( caller ))
			return;
			
		BuyBlock( this, caller, block );
	}
    if (cmd == this.getCommandID("returnBlocks"))
	{
		CBlob@ caller = getBlobByNetworkID( params.read_u16() );
		if ( caller !is null )
			ReturnBlocks( this, caller );
	}
}

bool canShoot( CBlob@ this )
{
	return !this.hasTag( "dead" ) && this.get_u32("fire time") + FIRE_RATE < getGameTime();
}

void onDie( CBlob@ this )
{
	
}

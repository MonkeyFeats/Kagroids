#define SERVER_ONLY
#include "MakeBlock.as"
#include "BlockCommon.as"


void onInit(CRules@ this)
{
}

void onTick(CRules@ this)
{
	u32 gameTime = getGameTime();
	
}

void onRestart( CRules@ this )
{
}

void onNewPlayerJoin( CRules@ this, CPlayer@ player )
{
	string pName = player.getUsername();
	print("New player joined. New count : " + getPlayersCount());
	if (getPlayersCount() <= 1)
	{
		//print("*** Restarting the map to be fair to the new player ***");
		getNet().server_SendMsg( "*** " + getPlayerCount() + " player(s) in map. Setting freebuild mode until more players join. ***" );
		this.set_bool( "freebuild", true );
	}
}

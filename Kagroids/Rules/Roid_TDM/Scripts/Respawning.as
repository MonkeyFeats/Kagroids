#define SERVER_ONLY
#include "ShipsCommon.as"

const string PLAYER_BLOB = "block";
const string SPAWN_TAG = "mothership";

bool oneTeamLeft = false;

shared class Respawn
{
	string username;
	u32 timeStarted;

	Respawn( const string _username, const u32 _timeStarted )
	{
		username = _username;
		timeStarted = _timeStarted;
	}
};

s32 getRandomMinimumTeam(CRules@ this, const int atLeast = -1)
{
    const int teamsCount = this.getTeamsNum();
    int[] playersperteam;
    for(int i = 0; i < teamsCount; i++)
        playersperteam.push_back(0);

    //gather the per team player counts
    const int playersCount = getPlayersCount();
    for(int i = 0; i < playersCount; i++)
    {
        CPlayer@ p = getPlayer(i);
        s32 pteam = p.getTeamNum();
        if(pteam >= 0 && pteam < teamsCount)
            playersperteam[pteam]++;
    }

    //calc the minimum player count, dequalify teams
    int minplayers = 1000;
    for(int i = 0; i < teamsCount; i++)
    {
        if ( playersperteam[i] < atLeast || getMothership(i) is null )
            playersperteam[i] += 500;
        minplayers = Maths::Min(playersperteam[i], minplayers);
    }
	
    //choose a random team with minimum player count
    s32 team;
    do
        team = XORRandom(teamsCount);
    while(playersperteam[team] > minplayers);

	//print( "ret Team : " + team );
    return team;
}

void onInit(CRules@ this)
{
	Respawn[] respawns;
	this.set("respawns", respawns);
	this.set_u8( "endCount", 0 );
    onRestart(this);
}

void onReload(CRules@ this)
{
    this.clear("respawns"); 
	this.set_u8( "endCount", 0 );	
    for (int i = 0; i < getPlayerCount(); i++)
    {
        CPlayer@ player = getPlayer(i);
        if ( player.getTeamNum() == this.getSpectatorTeamNum() )
			player.server_setTeamNum( this.getSpectatorTeamNum() );
        else if (player.getBlob() is null)
        {
            Respawn r(player.getUsername(), getGameTime());
            this.push("respawns", r);
        }
    }
}

void onRestart(CRules@ this)
{
	this.clear("respawns");
	this.set_u8( "endCount", 0 );
	//assign teams
    for (int i = 0; i < getPlayerCount(); i++)
	{
		CPlayer@ player = getPlayer(i);
		if ( player.getTeamNum() == this.getSpectatorTeamNum() )
			player.server_setTeamNum( this.getSpectatorTeamNum() );
		else
		{
			//print ( "onRestart: assigning " + player.getUsername() );
			player.server_setTeamNum( getRandomMinimumTeam(this) );
			Respawn r(player.getUsername(), getGameTime());
			this.push("respawns", r);
		}
	}

    this.SetCurrentState(GAME);
    this.SetGlobalMessage( "" );
}

void onPlayerRequestSpawn( CRules@ this, CPlayer@ player )
{
	if (!isRespawnAdded( this, player.getUsername()) && player.getTeamNum() != this.getSpectatorTeamNum())
	{
    	Respawn r(player.getUsername(), getGameTime());
    	this.push("respawns", r);
    }
}

void onTick( CRules@ this )
{
	const u32 gametime = getGameTime();
	if (this.isMatchRunning() && gametime % 30 == 0)
	{
		Respawn[]@ respawns;
		if (this.get("respawns", @respawns))
		{
			for (uint i = 0; i < respawns.length; i++)
			{
				Respawn@ r = respawns[i];
				if (r.timeStarted == 0 || r.timeStarted + this.playerrespawn_seconds*getTicksASecond() <= gametime)
				{
					SpawnPlayer( this, getPlayerByUsername( r.username ));
					respawns.erase(i);
					i = 0;
				}
			}
		}

        CBlob@[] cores;
        getBlobsByTag(SPAWN_TAG, cores);
		
        oneTeamLeft = ( cores.length <= 1 );
		u8 endCount = this.get_u8( "endCount" );
		
		if ( oneTeamLeft && endCount == 0 )//start endmatch countdown
			this.set_u8( "endCount", 5 );
		
		if ( endCount != 0 )
		{
			
        }
        else
            this.SetGlobalMessage( "" );
	}
}

CBlob@ SpawnPlayer( CRules@ this, CPlayer@ player )
{
    if (player !is null)
    {
        // remove previous players blob
        CBlob @blob = player.getBlob();		   
        if (blob !is null)
        {
            CBlob @blob = player.getBlob();
            blob.server_SetPlayer( null );
            blob.server_Die();
        }

        const u8 teamsCount = this.getTeamsNum();
		u8 team = player.getTeamNum();
        team = team > 32 ? getRandomMinimumTeam(this) : team;
        player.server_setTeamNum(team);
    
        CBlob@ ship = getMothership( 0 );
        if (ship !is null)
        {
			ship.server_SetPlayer( player );
        	return ship;
        }
		
    }

    return null;
}

bool isRespawnAdded( CRules@ this, const string username )
{
	Respawn[]@ respawns;
	if (this.get("respawns", @respawns))
	{
		for (uint i = 0; i < respawns.length; i++)
		{
			Respawn@ r = respawns[i];
			if (r.username == username)
				return true;
		}
	}
	return false;
}

Vec2f getSpawnPosition( const uint team )
{
    Vec2f[] spawns;			 
    if (getMap().getMarkers("spawn", spawns )) {
    	if (team >= 0 && team < spawns.length)
    		return spawns[team];
    }
    CMap@ map = getMap();
    return Vec2f( map.tilesize*map.tilemapwidth/2, map.tilesize*map.tilemapheight/2);
}

void onPlayerRequestTeamChange( CRules@ this, CPlayer@ player, u8 newteam )
{
    CBlob@ blob = player.getBlob();
	if (blob !is null)
        blob.server_Die();
	
	if ( newteam == 44 )//request from Block.as
		return;
		
	//if ( player.isMod() )
	{
		player.server_setTeamNum( newteam );
		if ( newteam != this.getSpectatorTeamNum())
			onPlayerRequestSpawn( this, player );
	}
	//else if (newteam == this.getSpectatorTeamNum())
   //{
   //    if (blob !is null && blob.getName() == "human")
   //        SpawnAsShark( this, player);
   //}
}

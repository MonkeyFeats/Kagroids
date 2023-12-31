namespace Block
{
	const int size = 8;

	enum Type 
	{
		A_HULL = 0,
		A_HULL2 = 1,
		A_HULL3 = 2,
		A_HULL4 = 3,
		A_HULL5 = 4,
		B_HULL = 5,
		B_HULL2 = 6,
		B_HULL3 = 7,
		B_HULL4 = 8,
		B_HULL5 = 9,

		COUPLING = 10,

		THRUSTER1 = 16,
		THRUSTER2 = 21,

		COMMAND_MODULE = 40
	};
					
	shared class Weights
	{
		f32 mothership;
		f32 wood;
		f32 ram;
		f32 solid;
	}
	
	Weights@ queryWeights( CRules@ this )
	{
		Block::Weights w;
		w.mothership = 1;
		w.wood = 1;
		w.solid = 1;

		this.set( "weights", w );
		return @w;
	}
	
	Weights@ getWeights( CRules@ this )
	{
		Block::Weights@ w;
		this.get( "weights", @w );
		
		if ( w is null )
			@w = Block::queryWeights( this );

		return w;
	}
	
	shared class Costs
	{
		u16 station;
		u16 wood;
		u16 ram;
		u16 solid;
		u16 door;
		u16 propeller;
		u16 ramEngine;
		u16 seat;
		u16 ramChair;
		u16 cannon;
		u16 harvester;
		u16 harpoon;
		u16 machinegun;
		u16 flak;
		u16 pointDefense;
		u16 launcher;
		u16 bomb;
		u16 coupling;
		u16 repulsor;
	}
	
	
	Costs@ getCosts( CRules@ this )
	{
		Block::Costs@ c;
		this.get( "costs", @c );
		
		if ( c is null )
		{
			@c = Block::queryCosts( this );
		}
			
		return c;
	}
	Costs@ queryCosts( CRules@ this )
	{
		ConfigFile cfg;
		if ( !cfg.loadFile( "SHRKTVars.cfg" ) ) 
			return null;
		
		print( "** Getting Costs from cfg" );
		Block::Costs c;

		this.set( "costs", c );

		return @c;
	}
	
	bool isSolid( const uint blockType )
	{
		return (blockType >= Block::A_HULL && blockType <= Block::B_HULL5);
	}

	bool isCore( const uint blockType )
	{
		return (blockType == Block::COMMAND_MODULE);// && blockType <= Block::COMMAND_MODULE+1);
	}

	bool isType( CBlob@ blob, const uint blockType )
	{
		return (blob.getSprite().getFrame() == blockType);
	}

	uint getType( CBlob@ blob )
	{
		return blob.getSprite().getFrame();
	}

	f32 getWeight ( const uint blockType )
	{
		CRules@ rules = getRules();
		
		Weights@ w = Block::getWeights( rules );

		if ( w is null )
		{
			warn( "** Couldn't get Weights!" );
			return 0;
		}
		
		switch(blockType)		
		{
			case Block::B_HULL:
				return 1;
			break;
			case Block::A_HULL:
				return 1;
			break;
			case Block::COMMAND_MODULE:
				return 1;
			break;			
		}
	
		return 1;
	}

	f32 getWeight ( CBlob@ blob )
	{
		return getWeight( getType(blob) );
	}
	
	u16 getCost ( const uint blockType )
	{
		CRules@ rules = getRules();
		
		Costs@ c = Block::getCosts( rules );

		if ( c is null )
		{
			warn( "** Couldn't get Costs!" );
			return 0;
		}
		
		switch(blockType)		
		{
			case Block::THRUSTER1:
				return c.propeller;
			break;
			case Block::THRUSTER2:
				return c.ramEngine;
			break;
			case Block::A_HULL:
				return c.wood;
			break;
			case Block::COMMAND_MODULE:
				return c.seat;
			break;
			//case Block::COUPLING:
			//	return c.coupling;
			//break;	
		}
	
		return 0;
	}

	const f32 BUTTON_RADIUS_FLOOR = 6;
	const f32 BUTTON_RADIUS_SOLID = 10;

};
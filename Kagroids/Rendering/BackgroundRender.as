
const string back_name = "pixel.png";
const string tex1_name = "WhiteNebula.png";
const string tex2_name = "ColourNebula.png";

const string planet_name = "brokenEarth.png";

const int wavelength = 128;
const f32 amplitude = 24.0;
const f32 z = -500.0;
const int framesize = 256;
const int gframesize = 256;

const uint width = (10000);
const uint height = (10000);

Vertex[] black_back;
Vertex[] neb1;
Vertex[] neb2;
Vertex[] planet_verts;

float[] model;

void onInit(CRules@ this)
{
	int back_id = Render::addScript(Render::layer_background, "BackgroundRender.as", "RenderSpace", 0.0f);
	Setup();
	//onRestart(this);
}

//void onRestart(CRules@ this)
//{
//	Setup();
//}

void Setup()
{
	Matrix::MakeIdentity(model);

	black_back.clear();
	neb1.clear();
	neb2.clear();

	planet_verts.clear();

	CMap@ map = getMap();

	float w2 = width/2;
	float h2 = height/2;

	black_back.push_back(Vertex(-w2, -h2, 		0, 0, 0, 	SColor(255,0,0,10)));
	black_back.push_back(Vertex( w2, -h2, 		0, 1, 0, 	SColor(255,0,0,10)));
	black_back.push_back(Vertex( w2,  h2,		0, 1, 1,  	SColor(255,0,0,10)));
	black_back.push_back(Vertex(-w2,  h2,		0, 0, 1,  	SColor(255,0,0,10)));
	
	neb1.push_back(Vertex(-w2, -h2, 	 	1, 0, 0, 									SColor(185,200,200,180)));
	neb1.push_back(Vertex( w2, -h2, 	 	1, width/framesize, 0, 					    SColor(185,200,200,180)));
	neb1.push_back(Vertex( w2,  h2,    		1, width/framesize, height/framesize,  		SColor(185,200,200,180)));
	neb1.push_back(Vertex(-w2,	 h2,    	1, 0, height/framesize,  					SColor(185,200,200,180)));
	
	neb2.push_back(Vertex(-w2, -h2, 	 	2, 0, 0, 									SColor(20, 210, 210, 210)));
	neb2.push_back(Vertex( w2, -h2, 	 	2, width/framesize, 0, 						SColor(20, 210, 210, 210)));
	neb2.push_back(Vertex( w2,  h2, 		2, width/framesize, height/framesize, 		SColor(20, 210, 210, 210)));
	neb2.push_back(Vertex(-w2,  h2, 		2, 0, height/framesize, 					SColor(20, 210, 210, 210)));

	//map isn't loaded yet for this
	//Vec2f mapmid( map.tilemapwidth*4.0, map.tilemapheight*4.0);
	Vec2f mapmid( 11*128, 11*128);

	planet_verts.push_back(Vertex( mapmid.x -800,  mapmid.y -800, 3,  0, 0, 		color_white ));
	planet_verts.push_back(Vertex( mapmid.x+ 800,  mapmid.y -800, 3,  1, 0, 		color_white ));
	planet_verts.push_back(Vertex( mapmid.x+ 800,  mapmid.y+ 800, 3,  1, 1, 		color_white ));
	planet_verts.push_back(Vertex( mapmid.x -800,  mapmid.y+ 800, 3,  0, 1, 		color_white ));
}


void RenderSpace(int id)
{
	Render::SetAlphaBlend(true);
	Render::RawQuads(back_name, black_back);

	float time = getGameTime()*0.1;
	f32 w1 =  -amplitude * Maths::Sin(Maths::Pi*2.0f*((time))/wavelength);
	f32 w2 =  -amplitude * Maths::Cos(Maths::Pi*2.0f*((time))/wavelength);

	Matrix::SetTranslation(model, w1*1.4, -w2*1.4, 0);			
	Render::SetModelTransform(model);
	Render::RawQuads(tex1_name, neb1);

	//Matrix::SetTranslation(model, w1, -w2, 0);			
	//Render::SetModelTransform(model);
	//Render::RawQuads(tex2_name, neb2);
			
	Matrix::SetTranslation(model, 0, 0, 0);
	Render::SetModelTransform(model);
	Render::RawQuads(planet_name, planet_verts);
}


void LoadRoidMapLoaders()
{
	printf("############ GAMEMODE " + sv_gamemode);

	RegisterFileExtensionScript("Scripts/MapLoaders/LoadRoidsPNG.as", "png");

	RegisterFileExtensionScript("Scripts/MapLoaders/GenerateFromKAGGen.as", "kaggen.cfg");
}

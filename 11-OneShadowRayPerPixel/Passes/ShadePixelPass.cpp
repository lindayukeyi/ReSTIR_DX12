#include "ShadePixelPass.h" 

// Some global vars, used to simplify changing shader location & entry points
namespace {
	// Where is our shader located?
	const char* kShadePixelShader = "Tutorial11\\shadePixel.hlsl";
};

bool ShadePixelPass::initialize(RenderContext* pRenderContext, ResourceManager::SharedPtr pResManager)
{
	// Stash a copy of our resource manager so we can get rendering resources
	mpResManager = pResManager;

	// Request textures
	mpResManager->requestTextureResource("FinalShadedImage");
	mpResManager->requestTextureResources({ "WorldPosition", "WorldNormal", "MaterialDiffuse" });

	mpResManager->requestTextureResource("EmittedLight");
	mpResManager->requestTextureResource("ToSample");
	mpResManager->requestTextureResource("Reservoir");
	mpResManager->requestTextureResource("SamplesSeenSoFar", ResourceFormat::R32Int, ResourceManager::kDefaultFlags);
		
	// Use the default gfx pipeline state
	mpGfxState = GraphicsState::create();

	// Create our shader
	mpShadePixelPass = FullscreenLaunch::create(kShadePixelShader);

	return true; 
}

void ShadePixelPass::execute(RenderContext* pRenderContext)
{
	auto outputFbo = mpResManager->createManagedFbo({ "FinalShadedImage" });

	auto shaderVars = mpShadePixelPass->getVars();
	
	shaderVars["gWsPos"] = mpResManager->getTexture("WorldPosition");
	shaderVars["gWsNorm"] = mpResManager->getTexture("WorldNormal");
	shaderVars["gMatDif"] = mpResManager->getTexture("MaterialDiffuse");

	shaderVars["emittedLight"] = mpResManager->getTexture("EmittedLight");
	shaderVars["toSample"] = mpResManager->getTexture("ToSample");
	shaderVars["reservoir"] = mpResManager->getTexture("Reservoir");
	shaderVars["M"] = mpResManager->getTexture("SamplesSeenSoFar");
	
	mpGfxState->setFbo(outputFbo);
	mpShadePixelPass->execute(pRenderContext, mpGfxState); // Shade the pixel

	/*
	std::string folderName = "C:\\Users\\keyiy\\Penn\\CIS565\\finalproject\\ReSTIR_DX12\\11-OneShadowRayPerPixel\\";

	std::string fileName = folderName + "worldPos\\" + std::to_string(mFrameCount) + ".EXR";
	mpResManager->getTexture("FinalShadedImage")->captureToFile(0, 0, fileName, Bitmap::FileFormat::ExrFile);

	fileName = folderName + "reservoirM\\" + std::to_string(mFrameCount) + ".EXR";
	mpResManager->getTexture("Jilin")->captureToFile(0, 0, fileName, Bitmap::FileFormat::ExrFile);

	fileName = folderName + "phat\\" + std::to_string(mFrameCount++) + ".EXR";
	mpResManager->getTexture("JilinS")->captureToFile(0, 0, fileName, Bitmap::FileFormat::ExrFile);
	*/
}
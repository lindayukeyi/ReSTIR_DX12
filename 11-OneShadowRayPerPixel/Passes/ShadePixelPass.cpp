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
	mpResManager->requestTextureResource("DenoisedImage");
	mpResManager->requestTextureResources({ "WorldPosition", "WorldNormal", "MaterialDiffuse",
											"MaterialSpecRough", "MaterialExtraParams", "Emissive" });
	mpResManager->requestTextureResource("EmittedLight");
	mpResManager->requestTextureResource("ToSample");
	mpResManager->requestTextureResource("Reservoir");
	mpResManager->requestTextureResource("SamplesSeenSoFar", ResourceFormat::R32Int, ResourceManager::kDefaultFlags);

	mpResManager->requestTextureResource("Jilin");
	mpResManager->requestTextureResource("JilinS");
	
	// Use the default gfx pipeline state
	mpGfxState = GraphicsState::create();

	// Create our shader
	mpShadePixelPass = FullscreenLaunch::create(kShadePixelShader);

	return true; 
}

void ShadePixelPass::execute(RenderContext* pRenderContext)
{
	auto outputFbo = mpResManager->createManagedFbo({ ResourceManager::kOutputChannel }); //mpResManager->getClearedTexture(ResourceManager::kOutputChannel, vec4(0.0f, 0.0f, 0.0f, 0.0f));
	auto denoisedImage = mpResManager->getClearedTexture("DenoisedImage", vec4(1, 0, 0, 1));

	auto shaderVars = mpShadePixelPass->getVars();
	
	shaderVars["gWsPos"] = mpResManager->getTexture("WorldPosition");
	shaderVars["gWsNorm"] = mpResManager->getTexture("WorldNormal");
	shaderVars["gMatDif"] = mpResManager->getTexture("MaterialDiffuse");
	shaderVars["gMatSpec"] = mpResManager->getTexture("MaterialSpecRough");
	shaderVars["gMatExtra"]	= mpResManager->getTexture("MaterialExtraParams");
	shaderVars["gMatEmissive"] = mpResManager->getTexture("Emissive");

	shaderVars["emittedLight"] = mpResManager->getTexture("EmittedLight");
	shaderVars["toSample"] = mpResManager->getTexture("ToSample");
	shaderVars["reservoir"] = mpResManager->getTexture("Reservoir");
	shaderVars["M"] = mpResManager->getTexture("SamplesSeenSoFar");

	shaderVars["jilin"] = mpResManager->getTexture("Jilin");

	mpGfxState->setFbo(outputFbo);
	mpShadePixelPass->execute(pRenderContext, mpGfxState); // Shade the pixel
	
	auto w = mpResManager->getTexture("FinalShadedImage")->getWidth();
	auto h = mpResManager->getTexture("FinalShadedImage")->getHeight();


		
	//mpResManager->getTexture("Jilin")->captureToFile(0, 0, "", Bitmap::FileFormat::ExrFile);

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
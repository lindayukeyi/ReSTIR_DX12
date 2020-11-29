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
	mpResManager->requestTextureResources({ "WorldPosition", "WorldNormal", "MaterialDiffuse",
											"MaterialSpecRough", "MaterialExtraParams", "Emissive" });
	mpResManager->requestTextureResource("EmittedLight");
	mpResManager->requestTextureResource("ToSample");
	mpResManager->requestTextureResource("SampleNormalArea");
	mpResManager->requestTextureResource("Reservoir");
	mpResManager->requestTextureResource("SamplesSeenSoFar", ResourceFormat::R32Int, ResourceManager::kDefaultFlags);

	mpResManager->requestTextureResource("LastEmittedLight");
	mpResManager->requestTextureResource("LastToSample");
	mpResManager->requestTextureResource("LastSampleNormalArea");
	mpResManager->requestTextureResource("LastReservoir");
	mpResManager->requestTextureResource("LastSamplesSeenSoFar", ResourceFormat::R32Int, ResourceManager::kDefaultFlags);
	mpResManager->requestTextureResource("LastWorldPosition");

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
	shaderVars["gMatSpec"] = mpResManager->getTexture("MaterialSpecRough");
	shaderVars["gMatExtra"]	= mpResManager->getTexture("MaterialExtraParams");
	shaderVars["gMatEmissive"] = mpResManager->getTexture("Emissive");

	shaderVars["emittedLight"] = mpResManager->getTexture("EmittedLight");
	shaderVars["toSample"] = mpResManager->getTexture("ToSample");
	shaderVars["sampleNormalArea"] = mpResManager->getTexture("SampleNormalArea");
	shaderVars["reservoir"] = mpResManager->getTexture("Reservoir");
	shaderVars["M"] = mpResManager->getTexture("SamplesSeenSoFar");

	mpGfxState->setFbo(outputFbo);
	mpShadePixelPass->execute(pRenderContext, mpGfxState); // Shade the pixel
	
	// Save the current reservoir to be used in next frame
	pRenderContext->blit(mpResManager->getTexture("EmittedLight")->getSRV(), mpResManager->getTexture("LastEmittedLight")->getRTV());
	pRenderContext->blit(mpResManager->getTexture("ToSample")->getSRV(), mpResManager->getTexture("LastToSample")->getRTV());
	pRenderContext->blit(mpResManager->getTexture("SampleNormalArea")->getSRV(), mpResManager->getTexture("LastSampleNormalArea")->getRTV());
	pRenderContext->blit(mpResManager->getTexture("Reservoir")->getSRV(), mpResManager->getTexture("LastReservoir")->getRTV());
	pRenderContext->blit(mpResManager->getTexture("SamplesSeenSoFar")->getSRV(), mpResManager->getTexture("LastSamplesSeenSoFar")->getRTV());
	pRenderContext->blit(mpResManager->getTexture("WorldPosition")->getSRV(), mpResManager->getTexture("LastWorldPosition")->getRTV());
}
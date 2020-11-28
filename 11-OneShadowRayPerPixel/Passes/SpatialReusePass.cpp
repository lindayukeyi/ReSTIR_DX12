#include "SpatialReusePass.h" 

// Some global vars, used to simplify changing shader location & entry points
namespace {
	// Where is our shader located?
	const char* kSpatialReuseShader = "Tutorial11\\spatialReuse.hlsl";
};

bool SpatialReusePass::initialize(RenderContext* pRenderContext, ResourceManager::SharedPtr pResManager)
{
	// Stash a copy of our resource manager so we can get rendering resources
	mpResManager = pResManager;

	// Request textures
	mpResManager->requestTextureResources({ "PingPongReservior", "PingpongToSample", "PingpongSampleNormalArea", "PingpongEmittedLight" });
	mpResManager->requestTextureResource("PingpongM", ResourceFormat::R32Int, ResourceManager::kDefaultFlags);
	mpResManager->requestTextureResources({ "WorldPosition", "WorldNormal", "MaterialDiffuse",
											"MaterialSpecRough", "MaterialExtraParams", "Emissive" });
	mpResManager->requestTextureResource("ToSample");
	mpResManager->requestTextureResource("SampleNormalArea");
	mpResManager->requestTextureResource("Reservoir");
	mpResManager->requestTextureResource("SamplesSeenSoFar", ResourceFormat::R32Int, ResourceManager::kDefaultFlags);
	mpResManager->requestTextureResource("EmittedLight");

	// Use the default gfx pipeline state
	mpGfxState = GraphicsState::create();

	// Create our shader
	mpSpatialReusePass = FullscreenLaunch::create(kSpatialReuseShader);

	return true;
}

void SpatialReusePass::execute(RenderContext* pRenderContext)
{
	auto outputFbo = mpResManager->createManagedFbo({ "PingPongReservior", "PingpongToSample", "PingpongSampleNormalArea", "PingpongEmittedLight", "PingpongM"});

	auto shaderVars = mpSpatialReusePass->getVars();

	shaderVars["gWsPos"] = mpResManager->getTexture("WorldPosition");
	shaderVars["gWsNorm"] = mpResManager->getTexture("WorldNormal");
	shaderVars["gMatDif"] = mpResManager->getTexture("MaterialDiffuse");
	shaderVars["gMatSpec"] = mpResManager->getTexture("MaterialSpecRough");
	shaderVars["gMatExtra"] = mpResManager->getTexture("MaterialExtraParams");
	shaderVars["gMatEmissive"] = mpResManager->getTexture("Emissive");

	shaderVars["toSample"] = mpResManager->getTexture("ToSample");
	shaderVars["sampleNormalArea"] = mpResManager->getTexture("SampleNormalArea");
	shaderVars["reservoir"] = mpResManager->getTexture("Reservoir");
	shaderVars["M"] = mpResManager->getTexture("SamplesSeenSoFar");
	shaderVars["emittedLight"] = mpResManager->getTexture("EmittedLight");

	mpGfxState->setFbo(outputFbo);
	mpSpatialReusePass->execute(pRenderContext, mpGfxState);
	pRenderContext->blit(mpResManager->getTexture("Reservoir")->getSRV(), outputFbo->getColorTexture(0)->getRTV());
	pRenderContext->blit(mpResManager->getTexture("ToSample")->getSRV(), outputFbo->getColorTexture(1)->getRTV());
	pRenderContext->blit(mpResManager->getTexture("SampleNormalArea")->getSRV(), outputFbo->getColorTexture(2)->getRTV());
	pRenderContext->blit(mpResManager->getTexture("EmittedLight")->getSRV(), outputFbo->getColorTexture(3)->getRTV());
	pRenderContext->blit(mpResManager->getTexture("SamplesSeenSoFar")->getSRV(), outputFbo->getColorTexture(4)->getRTV());

}
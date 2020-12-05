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
	mpResManager->requestTextureResources({ "PingpongReservoir", "PingpongToSample", "PingpongEmittedLight" });
	mpResManager->requestTextureResource("PingpongM", ResourceFormat::R32Int, ResourceManager::kDefaultFlags);

	mpResManager->requestTextureResources({ "WorldPosition", "WorldNormal", "MaterialDiffuse",
											"MaterialSpecRough", "MaterialExtraParams", "Emissive" });

	mpResManager->requestTextureResource("ToSample");
	mpResManager->requestTextureResource("Reservoir");
	mpResManager->requestTextureResource("SamplesSeenSoFar", ResourceFormat::R32Int, ResourceManager::kDefaultFlags);
	mpResManager->requestTextureResource("EmittedLight");

	mpResManager->requestTextureResource("Jilin"); // Debug

	// Use the default gfx pipeline state
	mpGfxState = GraphicsState::create();

	// Create our shader
	mpSpatialReusePass = FullscreenLaunch::create(kSpatialReuseShader);

	return true;
}

void SpatialReusePass::execute(RenderContext* pRenderContext)
{
	auto outputFbo = mpResManager->createManagedFbo({ "WorldPosition" });
	Texture::SharedPtr ppReservoir = mpResManager->getClearedTexture("PingpongReservoir", vec4(0, 0, 0, 0));
	Texture::SharedPtr ppToSample = mpResManager->getClearedTexture("PingpongToSample", vec4(0, 0, 0, 0));
	Texture::SharedPtr ppEmittedLight = mpResManager->getClearedTexture("PingpongEmittedLight", vec4(0, 0, 0, 0));
	Texture::SharedPtr ppM = mpResManager->getTexture("PingpongM");



	auto shaderVars = mpSpatialReusePass->getVars();

	shaderVars["gWsPos"] = outputFbo->getColorTexture(0);
	shaderVars["gWsNorm"] = mpResManager->getTexture("WorldNormal");
	shaderVars["gMatDif"] = mpResManager->getTexture("MaterialDiffuse");
	shaderVars["gMatSpec"] = mpResManager->getTexture("MaterialSpecRough");
	shaderVars["gMatExtra"] = mpResManager->getTexture("MaterialExtraParams");
	shaderVars["gMatEmissive"] = mpResManager->getTexture("Emissive");

	shaderVars["toSample"] = mpResManager->getTexture("ToSample");
	shaderVars["reservoir"] = mpResManager->getTexture("Reservoir");
	shaderVars["M"] = mpResManager->getTexture("SamplesSeenSoFar");
	shaderVars["emittedLight"] = mpResManager->getTexture("EmittedLight");

	shaderVars["jilin"] = mpResManager->getTexture("Jilin");
	shaderVars["ppReservoir"] = ppReservoir;
	shaderVars["ppToSample"] = ppToSample;
	shaderVars["ppEmittedLight"] = ppEmittedLight;
	shaderVars["ppM"] = ppM;


	shaderVars["MyCB"]["gFrameCount"] = mFrameCount++;

	mpGfxState->setFbo(outputFbo);
	mpSpatialReusePass->execute(pRenderContext, mpGfxState);
	pRenderContext->blit(mpResManager->getTexture("PingpongReservoir")->getSRV(), mpResManager->getTexture("Reservoir")->getRTV());
	pRenderContext->blit(mpResManager->getTexture("PingpongToSample")->getSRV(), mpResManager->getTexture("ToSample")->getRTV());
	pRenderContext->blit(mpResManager->getTexture("PingpongEmittedLight")->getSRV(), mpResManager->getTexture("EmittedLight")->getRTV());
	pRenderContext->blit(mpResManager->getTexture("PingpongM")->getSRV(), mpResManager->getTexture("SamplesSeenSoFar")->getRTV());
	/*
	pRenderContext->blit(outputFbo->getColorTexture(0)->getSRV(), mpResManager->getTexture("Reservoir")->getRTV());
	pRenderContext->blit(outputFbo->getColorTexture(1)->getSRV(), mpResManager->getTexture("ToSample")->getRTV());
	pRenderContext->blit(outputFbo->getColorTexture(2)->getSRV(), mpResManager->getTexture("EmittedLight")->getRTV());
	pRenderContext->blit(outputFbo->getColorTexture(3)->getSRV(), mpResManager->getTexture("SamplesSeenSoFar")->getRTV());
	*/
}
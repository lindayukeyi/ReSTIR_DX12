#include "TemporalReusePass.h"

namespace {
	const char *kTemporalReuseShader = "Tutorial11\\temporalReuse.hlsl";
};

void TemporalReusePass::initScene(RenderContext* pRenderContext, Scene::SharedPtr pScene) {
	mpScene = std::dynamic_pointer_cast<RtScene>(pScene);
}

bool TemporalReusePass::initialize(RenderContext* pRenderContext, ResourceManager::SharedPtr pResManager) {
	// Stash our resource manager
	mpResManager = pResManager;

	// Request textures
	mpResManager->requestTextureResource("TestOutput");
	mpResManager->requestTextureResources({ "WorldPosition", "WorldNormal", "MaterialDiffuse" });
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

	// Create our graphics state and accumulation shader
	mpGfxState = GraphicsState::create();
	mpTemporalReuse = FullscreenLaunch::create(kTemporalReuseShader);

	return true;
}

void TemporalReusePass::execute(RenderContext* pRenderContext) {
	auto myFBO = mpResManager->createManagedFbo({ "WorldPosition" });

	// Get textures
	Texture::SharedPtr wsNorm = mpResManager->getTexture("WorldNormal");
	Texture::SharedPtr matDif = mpResManager->getTexture("MaterialDiffuse");

	Texture::SharedPtr emittedLight = mpResManager->getTexture("EmittedLight");
	Texture::SharedPtr toSample = mpResManager->getTexture("ToSample");
	Texture::SharedPtr sampleNormalArea = mpResManager->getTexture("SampleNormalArea");
	Texture::SharedPtr reservoir = mpResManager->getTexture("Reservoir");
	Texture::SharedPtr M = mpResManager->getTexture("SamplesSeenSoFar");

	Texture::SharedPtr lastEmittedLight = mpResManager->getTexture("LastEmittedLight");
	Texture::SharedPtr lastToSample = mpResManager->getTexture("LastToSample");
	Texture::SharedPtr lastSampleNormalArea = mpResManager->getTexture("LastSampleNormalArea");
	Texture::SharedPtr lastReservoir = mpResManager->getTexture("LastReservoir");
	Texture::SharedPtr lastM = mpResManager->getTexture("LastSamplesSeenSoFar");
	Texture::SharedPtr lastWPos = mpResManager->getTexture("LastWorldPosition");
	
	// Set shader parameters
	auto shaderVars = mpTemporalReuse->getVars();
	shaderVars["MyCB"]["gFrameCount"] = mFrameCount++;
	shaderVars["MyCB"]["lastViewProjMat"] = mLastViewProjMatrix;
	mLastViewProjMatrix = mpScene->getActiveCamera()->getViewProjMatrix();

	shaderVars["gWsPos"] = myFBO->getColorTexture(0);
	shaderVars["gWsNorm"] = wsNorm;
	shaderVars["gMatDif"] = matDif;
	
	shaderVars["emittedLight"] = emittedLight;
	shaderVars["toSample"] = toSample;
	shaderVars["sampleNormalArea"] = sampleNormalArea;
	shaderVars["reservoir"] = reservoir;
	shaderVars["M"] = M;

	shaderVars["lastEmittedLight"] = lastEmittedLight;
	shaderVars["lastToSample"] = lastToSample;
	shaderVars["lastSampleNormalArea"] = lastSampleNormalArea;
	shaderVars["lastReservoir"] = lastReservoir;
	shaderVars["lastM"] = lastM;
	shaderVars["lastWPos"] = lastWPos;

	mpGfxState->setFbo(myFBO); // We need a FBO to make it work

	if (mFrameCount != 1) {
		// Skip the first frame since we do not have a frame to reuse
		mpTemporalReuse->execute(pRenderContext, mpGfxState);
	}
	
	// TODO: This should be done after spatial reuse pass
	// Save the current reservoir to be used in next frame
	pRenderContext->blit(emittedLight->getSRV(), lastEmittedLight->getRTV());
	pRenderContext->blit(toSample->getSRV(), lastToSample->getRTV());
	pRenderContext->blit(sampleNormalArea->getSRV(), lastSampleNormalArea->getRTV());
	pRenderContext->blit(reservoir->getSRV(), lastReservoir->getRTV());
	pRenderContext->blit(M->getSRV(), lastM->getRTV());
	pRenderContext->blit(myFBO->getColorTexture(0)->getSRV(), lastWPos->getRTV());
}
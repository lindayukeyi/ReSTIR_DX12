#include "TemporalReusePass.h"

namespace {
	const char *kTemporalReuseShader = "shaders\\temporalReuse.hlsl";
};

void TemporalReusePass::initScene(RenderContext* pRenderContext, Scene::SharedPtr pScene) {
	mpScene = std::dynamic_pointer_cast<RtScene>(pScene);
}

bool TemporalReusePass::hasCameraMoved() {
	return mpScene && mpScene->getActiveCamera() &&
		   (mLastViewProjMatrix != mpScene->getActiveCamera()->getViewProjMatrix());
}

bool TemporalReusePass::initialize(RenderContext* pRenderContext, ResourceManager::SharedPtr pResManager) {
	// Stash our resource manager
	mpResManager = pResManager;

	// Request textures
	mpResManager->requestTextureResources({ "WorldPosition", "WorldNormal", "MaterialDiffuse" });

	mpResManager->requestTextureResource("EmittedLight");
	mpResManager->requestTextureResource("ToSample");
	mpResManager->requestTextureResource("Reservoir");
	mpResManager->requestTextureResource("SamplesSeenSoFar", ResourceFormat::R32Int, ResourceManager::kDefaultFlags);

	mpResManager->requestTextureResources({ "PingpongReservoir", "PingpongToSample", "PingpongEmittedLight" });
	mpResManager->requestTextureResource("PingpongM", ResourceFormat::R32Int, ResourceManager::kDefaultFlags);

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
	Texture::SharedPtr reservoir = mpResManager->getTexture("Reservoir");
	Texture::SharedPtr M = mpResManager->getTexture("SamplesSeenSoFar");

	Texture::SharedPtr lastEmittedLight = mpResManager->getTexture("PingpongEmittedLight");
	Texture::SharedPtr lastToSample = mpResManager->getTexture("PingpongToSample");
	Texture::SharedPtr lastReservoir = mpResManager->getTexture("PingpongReservoir");
	Texture::SharedPtr lastM = mpResManager->getTexture("PingpongM");
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
	shaderVars["reservoir"] = reservoir;
	shaderVars["M"] = M;

	shaderVars["lastEmittedLight"] = lastEmittedLight;
	shaderVars["lastToSample"] = lastToSample;
	shaderVars["lastReservoir"] = lastReservoir;
	shaderVars["lastM"] = lastM;
	shaderVars["lastWPos"] = lastWPos;

	mpGfxState->setFbo(myFBO); // We need a FBO to make it work

	if (mFrameCount != 1) {
		// Skip the first frame since we do not have a frame to reuse
		mpTemporalReuse->execute(pRenderContext, mpGfxState);
	}

	// Save the current position to be used in next frame
	pRenderContext->blit(myFBO->getColorTexture(0)->getSRV(), mpResManager->getTexture("LastWorldPosition")->getRTV());
}
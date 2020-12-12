#include "AtrousDenoise.h" 

// Some global vars, used to simplify changing shader location & entry points
namespace {
	// Where is our shader located?
	const char* kShadePixelShader = "Tutorial11\\AtrousDenoise.hlsl";
};

bool AtrousDenoisePass::initialize(RenderContext* pRenderContext, ResourceManager::SharedPtr pResManager)
{
	// Stash a copy of our resource manager so we can get rendering resources
	mpResManager = pResManager;

	// Request textures
	mpResManager->requestTextureResource("DenoisedImage");
	mpResManager->requestTextureResource("PingpongDenoisedImage");
	mpResManager->requestTextureResource("FinalShadedImage");
	mpResManager->requestTextureResources({ "WorldPosition", "WorldNormal" });
	
	// Use the default gfx pipeline state
	mpGfxState = GraphicsState::create();

	// Create our shader
	mpAtrousDenoisePass = FullscreenLaunch::create(kShadePixelShader);

	return true; 
}

void AtrousDenoisePass::execute(RenderContext* pRenderContext)
{
	pRenderContext->blit(mpResManager->getTexture("FinalShadedImage")->getSRV(), mpResManager->getTexture("DenoisedImage")->getRTV());
	auto outputFbo = mpResManager->createManagedFbo({ "DenoisedImage" });

	auto shaderVars = mpAtrousDenoisePass->getVars();
	
	shaderVars["gWsPos"] = mpResManager->getTexture("WorldPosition");
	shaderVars["gWsNorm"] = mpResManager->getTexture("WorldNormal");
	shaderVars["gShadeImg"] = mpResManager->getTexture("PingpongDenoisedImage");
	shaderVars["gShadeImgOutput"] = mpResManager->getTexture("DenoisedImage");
	
	mpGfxState->setFbo(outputFbo);
	mpAtrousDenoisePass->execute(pRenderContext, mpGfxState);
}
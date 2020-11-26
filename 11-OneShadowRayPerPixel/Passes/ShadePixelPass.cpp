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

	// TODO : request textures
	mpResManager->requestTextureResource("FinalShadedImage");
	mpResManager->requestTextureResources({ "WorldPosition" });
	
	//mpResManager->requestTextureResource(ResourceManager::kOutputChannel);
	
	// Use the default gfx pipeline state
	mpGfxState = GraphicsState::create();

	// Create our shader
	mpShadePixelPass = FullscreenLaunch::create(kShadePixelShader);

	return true;
}

void ShadePixelPass::execute(RenderContext* pRenderContext)
{
	Texture::SharedPtr shadedImage = mpResManager->getTexture("FinalShadedImage");

	// If our texture is invalid, do nothing
	if (!shadedImage) return;

	auto shaderVars = mpShadePixelPass->getVars();

	shaderVars["gWsPos"] = mpResManager->getTexture("WorldPosition");
	
	mpShadePixelPass->execute(pRenderContext, mpGfxState);}
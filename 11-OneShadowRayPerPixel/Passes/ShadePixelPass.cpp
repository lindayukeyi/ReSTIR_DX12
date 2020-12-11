#include "ShadePixelPass.h"
#include <malloc.h>
#include "denoiseHelper.h"

// Some global vars, used to simplify changing shader location & entry points
namespace {
	// Where is our shader located?
	const char* kShadePixelShader = "Tutorial11\\shadePixel.hlsl";
	// What environment map should we load?
	const char* kEnvironmentMap = "Tutorial11\\MonValley_G_DirtRoad_3k.hdr";
};

bool ShadePixelPass::initialize(RenderContext* pRenderContext, ResourceManager::SharedPtr pResManager)
{
	// Stash a copy of our resource manager so we can get rendering resources
	mpResManager = pResManager;

	// Request textures
	mpResManager->requestTextureResource("FinalShadedImage");
	mpResManager->requestTextureResource("DenoisedImage");
	mpResManager->requestTextureResources({ "WorldPosition", "WorldNormal", "MaterialDiffuse" });

	mpResManager->requestTextureResource("EmittedLight");
	mpResManager->requestTextureResource("ToSample");
	mpResManager->requestTextureResource("Reservoir");
	mpResManager->requestTextureResource("SamplesSeenSoFar", ResourceFormat::R32Int, ResourceManager::kDefaultFlags);

	mpResManager->updateEnvironmentMap(kEnvironmentMap);

	// Use the default gfx pipeline state
	mpGfxState = GraphicsState::create();

	// Create our shader
	mpShadePixelPass = FullscreenLaunch::create(kShadePixelShader);

	return true; 
}

void ShadePixelPass::execute(RenderContext* pRenderContext)
{
	auto myFBO = mpResManager->createManagedFbo({ "WorldPosition" });

	auto shaderVars = mpShadePixelPass->getVars();
	
	shaderVars["shadedImage"] = mpResManager->getTexture("FinalShadedImage");
	shaderVars["gWsPos"] = myFBO->getColorTexture(0);
	shaderVars["gWsNorm"] = mpResManager->getTexture("WorldNormal");
	shaderVars["gMatDif"] = mpResManager->getTexture("MaterialDiffuse");

	shaderVars["emittedLight"] = mpResManager->getTexture("EmittedLight");
	shaderVars["toSample"] = mpResManager->getTexture("ToSample");
	shaderVars["reservoir"] = mpResManager->getTexture("Reservoir");
	shaderVars["M"] = mpResManager->getTexture("SamplesSeenSoFar");

	shaderVars["gEnvMap"] = mpResManager->getTexture(ResourceManager::kEnvironmentMap);
	
	mpGfxState->setFbo(myFBO);
	mpShadePixelPass->execute(pRenderContext, mpGfxState); // Shade the pixel
	
	auto width = mpResManager->getWidth();
	auto height = mpResManager->getHeight();

	if (mFrameCount++ == 0) {
		toDenoisePtr = (float*)malloc(sizeof(float) * 3 * width * height);
		f4p = (float*)malloc(sizeof(float) * 4 * width * height);
	}

	mpResManager->getTexture("FinalShadedImage")->getData(toDenoisePtr);
	

	denoise_helper(toDenoisePtr, NULL, NULL, toDenoisePtr, width, height, 0, 0, 0);

	for (auto y = 0u, ct = 0u; y < height; y++) {
		float* rowStart = (float*)f4p;
		rowStart += width * 4;
		for (auto x = 0u; x < width; x++) {
			rowStart[4 * x + 0] = toDenoisePtr[ct + 0];
			rowStart[4 * x + 1] = toDenoisePtr[ct + 1];
			rowStart[4 * x + 2] = toDenoisePtr[ct + 2];
			rowStart[4 * x + 3] = 1.f;
			ct += 3;
		}
	}

	Texture::SharedPtr denoisedTexture = Texture::create2D(width, height, ResourceFormat::RGBA32Float, 1, 1, (uint8_t*)f4p);
	if (denoisedTexture) {
		mpResManager->manageTextureResource("DenoisedImage", denoisedTexture);
	}


	/*std::string folderName = "C:\\Users\\keyiy\\Penn\\CIS565\\finalproject\\ReSTIR_DX12\\11-OneShadowRayPerPixel\\";

	std::string fileName = folderName + "worldPos\\" + std::to_string(mFrameCount) + ".exr";
	mpResManager->getTexture("FinalShadedImage")->captureToFile(0, 0, fileName, Bitmap::FileFormat::ExrFile);*/

	/*std::string folderName = "C:\\Users\\keyiy\\Penn\\CIS565\\finalproject\\ReSTIR_DX12\\11-OneShadowRayPerPixel\\";

	std::string fileName = folderName + "worldPos\\" + std::to_string(mFrameCount) + ".Pfm";
	mpResManager->getTexture("EmittedLight")->captureToFile(0, 0, fileName, Bitmap::FileFormat::PfmFile);
	
	fileName = folderName + "reservoirM\\" + std::to_string(mFrameCount) + ".EXR";
	mpResManager->getTexture("Jilin")->captureToFile(0, 0, fileName, Bitmap::FileFormat::ExrFile);

	fileName = folderName + "phat\\" + std::to_string(mFrameCount++) + ".EXR";
	mpResManager->getTexture("JilinS")->captureToFile(0, 0, fileName, Bitmap::FileFormat::ExrFile);
	*/
}
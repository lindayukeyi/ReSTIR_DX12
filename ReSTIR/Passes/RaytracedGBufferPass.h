#pragma once
#include "../SharedUtils/RenderPass.h"
#include "../SharedUtils/SimpleVars.h"
#include "../SharedUtils/RayLaunch.h"

class RayTracedGBufferPass : public ::RenderPass, inherit_shared_from_this<::RenderPass, RayTracedGBufferPass>
{
public:
	using SharedPtr = std::shared_ptr<RayTracedGBufferPass>;

	static SharedPtr create() { return SharedPtr(new RayTracedGBufferPass()); }
	virtual ~RayTracedGBufferPass() = default;

protected:
	RayTracedGBufferPass() : ::RenderPass("Ray Traced G-Buffer", "Ray Traced G-Buffer Options") {}

	// Implementation of RenderPass interface
	bool initialize(RenderContext* pRenderContext, ResourceManager::SharedPtr pResManager) override;
	void execute(RenderContext* pRenderContext) override;
	void initScene(RenderContext* pRenderContext, Scene::SharedPtr pScene) override;

	// The base RenderPass class defines a number of methods that we can override to 
	//    specify what properties this pass has.  
	bool requiresScene() override { return true; }
	bool usesRayTracing() override { return true; }

	// Internal pass state
	RayLaunch::SharedPtr        mpRays;            ///< Our wrapper around a DX Raytracing pass
	RtScene::SharedPtr          mpScene;           ///<  A copy of our scene

	// What's our background color?
	vec3                        mBgColor = vec3(0.5f, 0.5f, 1.0f);

	// Frame count used for seed generation
	uint32_t mFrameCount = 0;
};

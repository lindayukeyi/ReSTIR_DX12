#pragma once

#include "../SharedUtils/RenderPass.h"
#include "../SharedUtils/SimpleVars.h"
#include "../SharedUtils/FullscreenLaunch.h"

class TemporalReusePass : public ::RenderPass, inherit_shared_from_this<::RenderPass, TemporalReusePass>
{
public:
	using SharedPtr = std::shared_ptr<TemporalReusePass>;
	using SharedConstPtr = std::shared_ptr<const TemporalReusePass>;

	static SharedPtr create() { return SharedPtr(new TemporalReusePass()); }
	virtual ~TemporalReusePass() = default;

protected:
	TemporalReusePass() : ::RenderPass("TemporalReusePass", "TemporalReusePass  Options") {}

	// Implementation of SimpleRenderPass interface
	bool initialize(RenderContext* pRenderContext, ResourceManager::SharedPtr pResManager) override;
	void initScene(RenderContext* pRenderContext, Scene::SharedPtr pScene) override;
	void execute(RenderContext* pRenderContext) override;
	
	// Override some functions that provide information to the RenderPipeline class
	bool appliesPostprocess() override { return true; }

	bool hasCameraMoved();
	
	// State for our accumulation shader
	FullscreenLaunch::SharedPtr   mpTemporalReuse;
	GraphicsState::SharedPtr      mpGfxState;

	// We stash a copy of our current scene to get the view projection matrix.
	Scene::SharedPtr              mpScene;
	mat4                          mLastViewProjMatrix;

	uint32_t                      mFrameCount = 0;
};

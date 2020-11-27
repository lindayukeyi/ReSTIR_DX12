#pragma once
#include "../SharedUtils/RenderPass.h"
#include "../SharedUtils/FullscreenLaunch.h"

class SpatialReusePass : public ::RenderPass, inherit_shared_from_this<::RenderPass, SpatialReusePass>
{
public:
	using SharedPtr = std::shared_ptr<SpatialReusePass>;
	using SharedConstPtr = std::shared_ptr<const SpatialReusePass>;

	static SharedPtr create() { return SharedPtr(new SpatialReusePass()); }
	virtual ~SpatialReusePass() = default;

protected:
	SpatialReusePass() : ::RenderPass("SpatialReusePass", "SpatialReusePass  Options") {}

	// Implementation of RenderPass interface
	bool initialize(RenderContext* pRenderContext, ResourceManager::SharedPtr pResManager) override;
	void execute(RenderContext* pRenderContext) override;

	// Override some functions that provide information to the RenderPipeline class
	bool usesRasterization() override { return true; }

	// Internal pass state
	FullscreenLaunch::SharedPtr   mpSpatialReusePass;         ///< Our accumulation shader state
	GraphicsState::SharedPtr      mpGfxState;             ///< Our graphics pipeline state
	uint32_t                      mFrameCount = 0x1337u;  ///< A frame counter to vary random numbers over time
};

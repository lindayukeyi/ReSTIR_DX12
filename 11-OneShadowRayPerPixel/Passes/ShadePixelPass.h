#pragma once
#include "../SharedUtils/RenderPass.h"
#include "../SharedUtils/FullscreenLaunch.h"

class ShadePixelPass : public ::RenderPass, inherit_shared_from_this<::RenderPass, ShadePixelPass>
{
public:
    using SharedPtr = std::shared_ptr<ShadePixelPass>;
    using SharedConstPtr = std::shared_ptr<const ShadePixelPass>;

    static SharedPtr create() { return SharedPtr(new ShadePixelPass()); }
    virtual ~ShadePixelPass() = default;

protected:
    ShadePixelPass() : ::RenderPass("ShadePixelPass", "ShadePixelPass  Options") {}

    // Implementation of RenderPass interface
    bool initialize(RenderContext* pRenderContext, ResourceManager::SharedPtr pResManager) override;
    void execute(RenderContext* pRenderContext) override;

    // Override some functions that provide information to the RenderPipeline class
    bool usesRasterization() override { return true; }
	bool usesEnvironmentMap() override { return true; }

	// Internal pass state
	FullscreenLaunch::SharedPtr   mpShadePixelPass;         ///< Our accumulation shader state
	GraphicsState::SharedPtr      mpGfxState;             ///< Our graphics pipeline state
    uint32_t                      mFrameCount = 0;  ///< A frame counter to vary random numbers over time
};

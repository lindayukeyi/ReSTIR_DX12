#pragma once
#include "../SharedUtils/RenderPass.h"
#include "../SharedUtils/FullscreenLaunch.h"

class AtrousDenoisePass : public ::RenderPass, inherit_shared_from_this<::RenderPass, AtrousDenoisePass>
{
public:
    using SharedPtr = std::shared_ptr<AtrousDenoisePass>;
    using SharedConstPtr = std::shared_ptr<const AtrousDenoisePass>;

	static SharedPtr create(int k) { return SharedPtr(new AtrousDenoisePass(k)); }
    virtual ~AtrousDenoisePass() = default;

protected:
	AtrousDenoisePass(int k) : ::RenderPass("AtrousDenoisePass", "AtrousDenoisePass  Options") { this->k = k; }
	int k;
    // Implementation of RenderPass interface
    bool initialize(RenderContext* pRenderContext, ResourceManager::SharedPtr pResManager) override;
    void execute(RenderContext* pRenderContext) override;

    // Override some functions that provide information to the RenderPipeline class
    bool usesRasterization() override { return true; }

	// Internal pass state
	FullscreenLaunch::SharedPtr   mpAtrousDenoisePass;         ///< Our accumulation shader state
	GraphicsState::SharedPtr      mpGfxState;             ///< Our graphics pipeline state
    uint32_t                      mFrameCount = 0;  ///< A frame counter to vary random numbers over time
};

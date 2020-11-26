// Shade pixel

RWTexture2D<float4> gWsPos;
//RWTexture2D<float4> gWsNorm;

float4 main(float2 texC : TEXCOORD, float4 pos : SV_Position) : SV_Target0
{
	uint2 pixelPos = (uint2)pos.xy; // Where is this pixel on screen?
	return gWsPos[pixelPos];
}

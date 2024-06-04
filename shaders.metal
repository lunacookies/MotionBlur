struct RasterizerData
{
	float4 position [[position]];
	float4 color;
};

constant float4 positions[] = {
        {0, 0.5, 0, 1},
        {-0.5, -0.5, 0, 1},
        {0.5, -0.5, 0, 1},
};

vertex RasterizerData
VertexFunction(uint vertex_id [[vertex_id]])
{
	RasterizerData output = {0};
	output.position = positions[vertex_id];
	output.color = float4(1, 1, 1, 1);
	return output;
}

fragment float4
FragmentFunction(RasterizerData input [[stage_in]])
{
	return input.color;
}

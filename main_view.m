@interface MainView : NSView
@end

@implementation MainView

id<MTLDevice> device;
CAMetalLayer *metalLayer;
id<MTLCommandQueue> commandQueue;
CADisplayLink *displayLink;

id<MTLRenderPipelineState> pipelineState;
id<MTLRenderPipelineState> pipelineStateClear;
id<MTLRenderPipelineState> pipelineStateAccumulate;
id<MTLRenderPipelineState> pipelineStateFlatten;

id<MTLTexture> offscreenTexture;
id<MTLTexture> accumulatorTexture;

- (instancetype)initWithFrame:(NSRect)frame
{
	self = [super initWithFrame:frame];

	self.wantsLayer = YES;
	self.layer = [CAMetalLayer layer];
	device = MTLCreateSystemDefaultDevice();
	metalLayer = (CAMetalLayer *)self.layer;
	metalLayer.device = device;

	commandQueue = [device newCommandQueue];

	NSBundle *bundle = [NSBundle mainBundle];
	NSURL *libraryURL = [bundle URLForResource:@"shaders" withExtension:@"metallib"];
	id<MTLLibrary> library = [device newLibraryWithURL:libraryURL error:nil];

	{
		MTLRenderPipelineDescriptor *descriptor =
		        [[MTLRenderPipelineDescriptor alloc] init];
		descriptor.colorAttachments[0].pixelFormat = MTLPixelFormatRGBA16Float;
		descriptor.colorAttachments[1].pixelFormat = MTLPixelFormatRGBA16Float;
		descriptor.colorAttachments[2].pixelFormat = metalLayer.pixelFormat;
		descriptor.vertexFunction = [library newFunctionWithName:@"VertexFunction"];
		descriptor.fragmentFunction = [library newFunctionWithName:@"FragmentFunction"];
		pipelineState = [device newRenderPipelineStateWithDescriptor:descriptor error:nil];
	}

	{
		MTLRenderPipelineDescriptor *descriptor =
		        [[MTLRenderPipelineDescriptor alloc] init];
		descriptor.colorAttachments[0].pixelFormat = MTLPixelFormatRGBA16Float;
		descriptor.colorAttachments[1].pixelFormat = MTLPixelFormatRGBA16Float;
		descriptor.colorAttachments[2].pixelFormat = metalLayer.pixelFormat;
		descriptor.vertexFunction = [library newFunctionWithName:@"ClearVertexFunction"];
		descriptor.fragmentFunction =
		        [library newFunctionWithName:@"ClearFragmentFunction"];
		pipelineStateClear = [device newRenderPipelineStateWithDescriptor:descriptor
		                                                            error:nil];
	}

	{
		MTLRenderPipelineDescriptor *descriptor =
		        [[MTLRenderPipelineDescriptor alloc] init];
		descriptor.colorAttachments[0].pixelFormat = MTLPixelFormatRGBA16Float;
		descriptor.colorAttachments[1].pixelFormat = MTLPixelFormatRGBA16Float;
		descriptor.colorAttachments[2].pixelFormat = metalLayer.pixelFormat;
		descriptor.vertexFunction =
		        [library newFunctionWithName:@"AccumulateVertexFunction"];
		descriptor.fragmentFunction =
		        [library newFunctionWithName:@"AccumulateFragmentFunction"];
		pipelineStateAccumulate = [device newRenderPipelineStateWithDescriptor:descriptor
		                                                                 error:nil];
	}

	{
		MTLRenderPipelineDescriptor *descriptor =
		        [[MTLRenderPipelineDescriptor alloc] init];
		descriptor.colorAttachments[0].pixelFormat = MTLPixelFormatRGBA16Float;
		descriptor.colorAttachments[1].pixelFormat = MTLPixelFormatRGBA16Float;
		descriptor.colorAttachments[2].pixelFormat = metalLayer.pixelFormat;
		descriptor.vertexFunction = [library newFunctionWithName:@"FlattenVertexFunction"];
		descriptor.fragmentFunction =
		        [library newFunctionWithName:@"FlattenFragmentFunction"];
		pipelineStateFlatten = [device newRenderPipelineStateWithDescriptor:descriptor
		                                                              error:nil];
	}

	displayLink = [self displayLinkWithTarget:self selector:@selector(render)];
	[displayLink addToRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];

	CAFrameRateRange range = {0};
	range.maximum = 60;
	range.minimum = 60;
	range.preferred = 60;
	displayLink.preferredFrameRateRange = range;

	return self;
}

- (void)render
{
	double targetTimestamp = displayLink.targetTimestamp;

	id<MTLCommandBuffer> commandBuffer = [commandQueue commandBuffer];

	uint64_t subframeCount = 128;
	double subframeDeltaTime =
	        (displayLink.targetTimestamp - displayLink.timestamp) / subframeCount;

	id<CAMetalDrawable> drawable = [metalLayer nextDrawable];

	MTLRenderPassDescriptor *descriptor = [MTLRenderPassDescriptor renderPassDescriptor];

	descriptor.colorAttachments[0].texture = offscreenTexture;
	descriptor.colorAttachments[0].storeAction = MTLStoreActionDontCare;
	descriptor.colorAttachments[0].loadAction = MTLLoadActionDontCare;

	descriptor.colorAttachments[1].texture = accumulatorTexture;
	descriptor.colorAttachments[1].storeAction = MTLStoreActionStore;
	descriptor.colorAttachments[1].loadAction = MTLLoadActionClear;
	descriptor.colorAttachments[1].clearColor = MTLClearColorMake(0, 0, 0, 0);

	descriptor.colorAttachments[2].texture = drawable.texture;
	descriptor.colorAttachments[2].storeAction = MTLStoreActionStore;
	descriptor.colorAttachments[2].loadAction = MTLLoadActionClear;
	descriptor.colorAttachments[2].clearColor = MTLClearColorMake(0, 0, 0, 0);

	id<MTLRenderCommandEncoder> encoder =
	        [commandBuffer renderCommandEncoderWithDescriptor:descriptor];

	for (uint64_t i = 0; i < subframeCount; i++)
	{
		[encoder setRenderPipelineState:pipelineStateClear];
		[encoder drawPrimitives:MTLPrimitiveTypeTriangle vertexStart:0 vertexCount:6];

		[self renderSubframeWithEncoder:encoder
		                targetTimestamp:targetTimestamp + i * subframeDeltaTime];

		[encoder setRenderPipelineState:pipelineStateAccumulate];
		[encoder drawPrimitives:MTLPrimitiveTypeTriangle vertexStart:0 vertexCount:6];
	}

	uint32_t subframeCount32 = (uint32_t)subframeCount;
	[encoder setRenderPipelineState:pipelineStateFlatten];
	[encoder setFragmentBytes:&subframeCount32 length:sizeof(subframeCount32) atIndex:0];
	[encoder drawPrimitives:MTLPrimitiveTypeTriangle vertexStart:0 vertexCount:6];

	[encoder endEncoding];

	[commandBuffer presentDrawable:drawable];
	[commandBuffer commit];
}

- (void)renderSubframeWithEncoder:(id<MTLRenderCommandEncoder>)encoder
                  targetTimestamp:(double)targetTimestamp
{
	simd_float2 resolution = 0;
	resolution.x = (float)self.frame.size.width;
	resolution.y = (float)self.frame.size.height;

	static simd_float2 position = 0;
	position.x = 400 * (float)cos(10 * targetTimestamp);
	position.y = 400 * (float)sin(10 * targetTimestamp * 2);

	float size = 100;

	[encoder setRenderPipelineState:pipelineState];
	[encoder setVertexBytes:&resolution length:sizeof(resolution) atIndex:0];
	[encoder setVertexBytes:&position length:sizeof(position) atIndex:1];
	[encoder setVertexBytes:&size length:sizeof(size) atIndex:2];
	[encoder drawPrimitives:MTLPrimitiveTypeTriangle vertexStart:0 vertexCount:3];
}

- (void)viewDidChangeBackingProperties
{
	[super viewDidChangeBackingProperties];
	metalLayer.contentsScale = self.window.backingScaleFactor;
	[self updateTextures];
}

- (void)setFrameSize:(NSSize)size
{
	[super setFrameSize:size];

	float scaleFactor = (float)self.window.backingScaleFactor;
	if (scaleFactor == 0)
	{
		return;
	}
	size.width *= scaleFactor;
	size.height *= scaleFactor;
	metalLayer.drawableSize = size;

	[self updateTextures];
}

- (void)updateTextures
{
	float scaleFactor = (float)self.window.backingScaleFactor;
	NSSize size = self.frame.size;
	size.width *= scaleFactor;
	size.height *= scaleFactor;

	MTLTextureDescriptor *descriptor = [[MTLTextureDescriptor alloc] init];
	descriptor.width = (NSUInteger)size.width;
	descriptor.height = (NSUInteger)size.height;
	descriptor.pixelFormat = MTLPixelFormatRGBA16Float;
	descriptor.usage = MTLTextureUsageRenderTarget;

	descriptor.storageMode = MTLStorageModeMemoryless;
	offscreenTexture = [device newTextureWithDescriptor:descriptor];
	offscreenTexture.label = @"Offscreen Texture";

	descriptor.storageMode = MTLStorageModePrivate;
	accumulatorTexture = [device newTextureWithDescriptor:descriptor];
	accumulatorTexture.label = @"Accumulator Texture";
}

@end

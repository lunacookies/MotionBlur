@interface MainView : NSView
@end

@implementation MainView

id<MTLDevice> device;
CAMetalLayer *metalLayer;
id<MTLCommandQueue> commandQueue;
CADisplayLink *displayLink;
id<MTLRenderPipelineState> pipelineState;

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

	MTLRenderPipelineDescriptor *descriptor = [[MTLRenderPipelineDescriptor alloc] init];
	descriptor.colorAttachments[0].pixelFormat = metalLayer.pixelFormat;
	descriptor.vertexFunction = [library newFunctionWithName:@"VertexFunction"];
	descriptor.fragmentFunction = [library newFunctionWithName:@"FragmentFunction"];
	pipelineState = [device newRenderPipelineStateWithDescriptor:descriptor error:nil];

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
	id<CAMetalDrawable> drawable = [metalLayer nextDrawable];

	MTLRenderPassDescriptor *descriptor = [MTLRenderPassDescriptor renderPassDescriptor];
	descriptor.colorAttachments[0].texture = drawable.texture;
	descriptor.colorAttachments[0].storeAction = MTLStoreActionStore;
	descriptor.colorAttachments[0].loadAction = MTLLoadActionClear;
	descriptor.colorAttachments[0].clearColor = MTLClearColorMake(0.5, 0.5, 0.5, 1);

	id<MTLRenderCommandEncoder> encoder =
	        [commandBuffer renderCommandEncoderWithDescriptor:descriptor];

	[encoder setRenderPipelineState:pipelineState];

	simd_float2 resolution = 0;
	resolution.x = (float)self.frame.size.width;
	resolution.y = (float)self.frame.size.height;
	[encoder setVertexBytes:&resolution length:sizeof(resolution) atIndex:0];

	static simd_float2 position = 0;
	position.x = 400 * (float)cos(10 * targetTimestamp);
	position.y = 400 * (float)sin(10 * targetTimestamp * 2);
	[encoder setVertexBytes:&position length:sizeof(position) atIndex:1];

	float size = 100;
	[encoder setVertexBytes:&size length:sizeof(size) atIndex:2];

	[encoder drawPrimitives:MTLPrimitiveTypeTriangle vertexStart:0 vertexCount:3];
	[encoder endEncoding];

	[commandBuffer presentDrawable:drawable];
	[commandBuffer commit];
}

- (void)viewDidChangeBackingProperties
{
	[super viewDidChangeBackingProperties];
	metalLayer.contentsScale = self.window.backingScaleFactor;
}

- (void)setFrameSize:(NSSize)size
{
	[super setFrameSize:size];
	float scaleFactor = (float)self.window.backingScaleFactor;
	size.width *= scaleFactor;
	size.height *= scaleFactor;
	metalLayer.drawableSize = size;
}

@end

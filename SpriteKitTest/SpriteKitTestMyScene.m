//
//  SpriteKitTestMyScene.m
//  SpriteKitTest
//
//  Created by Ewart Wigmans on 13-11-13.
//  Copyright (c) 2013 Ewart Wigmans. All rights reserved.
//

@import CoreMotion;
@import AVFoundation;
#import "SpriteKitTestMyScene.h"
#import "FMMParallaxNode.h"

#define kScoreHudName @"scoreHud"
#define kLivesHudName @"healthHud"
#define kBombHudName @"bombHud"

typedef enum {
    kEndReasonWin,
    kEndReasonLose
} EndReason;

static const uint8_t shipCategory = 0x1 << 0;
static const uint8_t laserCategory = 0x1 << 1;
static const uint8_t enemyCategory = 0x1 << 2;

@implementation SpriteKitTestMyScene

{
    SKSpriteNode *_ship;
    FMMParallaxNode *_parallaxNodeBackgrounds;
    FMMParallaxNode *_parallaxSpaceDust;
    CMMotionManager *_motionManager;
    double _nextAsteroidSpawn;
    AVAudioPlayer *_backgroundAudioPlayer;
    int _lives;
    int _score;
    int _bombs;
    double _gameOverTime;
    bool _gameOver;
}


-(id)initWithSize:(CGSize)size
{
    if (self = [super initWithSize:size])
    {
        /* Setup your scene here */
        NSLog(@"SKScene:initWithSize %f x %f",size.width,size.height);
        self.backgroundColor = [SKColor blackColor];
       
        self.physicsBody = [SKPhysicsBody bodyWithEdgeLoopFromRect:self.frame];
        self.physicsWorld.gravity = CGVectorMake(0, 0);
		self.physicsWorld.contactDelegate = self;
        
        
#pragma mark - Game Backgrounds
        NSArray *parallaxBackgroundNames = @[@"bg_galaxy.png", @"bg_planetsunrise.png",
                                             @"bg_spacialanomaly.png", @"bg_spacialanomaly2.png"];
        CGSize planetSizes = CGSizeMake(200.0, 200.0);
        _parallaxNodeBackgrounds = [[FMMParallaxNode alloc] initWithBackgrounds:parallaxBackgroundNames
                                                                           size:planetSizes
                                                           pointsPerSecondSpeed:10.0];
        _parallaxNodeBackgrounds.position = CGPointMake(size.width/2.0, size.height/2.0);
        [_parallaxNodeBackgrounds randomizeNodesPositions];

        [self addChild:_parallaxNodeBackgrounds];
        
        NSArray *parallaxBackground2Names = @[@"bg_front_spacedust.png",@"bg_front_spacedust.png"];
        _parallaxSpaceDust = [[FMMParallaxNode alloc] initWithBackgrounds:parallaxBackground2Names
                                                                     size:size
                                                     pointsPerSecondSpeed:25.0];
        _parallaxSpaceDust.position = CGPointMake(0, 0);
        [self addChild:_parallaxSpaceDust];
		
#pragma mark - Setup Sprite for the ship
        [self LoadSpaceShip];

#pragma mark - Setup the Accelerometer to move the ship
        _motionManager = [[CMMotionManager alloc] init];

#pragma mark - Setup the stars to appear as particles
        [self addChild:[self loadStarEmitterNode:@"stars1"]];
        [self addChild:[self loadStarEmitterNode:@"stars2"]];
        [self addChild:[self loadStarEmitterNode:@"stars3"]];

#pragma mark - make the Hud
        [self setupHud];
        
#pragma mark - Start the actual game
        [self startBackgroundMusic];
        [self startTheGame];
        
    }
    return self;
}

- (void)startTheGame
{
    _lives = 3;
    _bombs = 3;
    double curTime = CACurrentMediaTime();
    _gameOverTime = curTime + 30.0;
    _gameOver = NO;
    _nextAsteroidSpawn = 0;
    _score = 0;
    
    [self UpdateHud];
    
    _ship.hidden = NO;
    _ship.position = CGPointMake(self.frame.size.width * 0.1, CGRectGetMidY(self.frame));
    
    //setup to handle accelerometer readings using CoreMotion Framework
    [self startMonitoringAcceleration];
    
}

#pragma mark process touches

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event
{
    /* Called when a touch begins */
    
    //check if they touched your a Label
    for (UITouch *touch in touches)
    {
        SKNode *n = [self nodeAtPoint:[touch locationInNode:self]];
        if (n != self && [n.name isEqual: @"restartLabel"])
        {
            [[self childNodeWithName:@"restartLabel"] removeFromParent];
            [[self childNodeWithName:@"winLoseLabel"] removeFromParent];
            [self startTheGame];
            return;
        }
        else if(n != self && [n.name isEqual: kBombHudName])
        {
            if (_bombs > 0)
            {
                [self BombDropped];
                return;
            }
        }
    }
    
    //do not process anymore touches since it's game over
    if (_gameOver)
    {
        return;
    }
    
    [self FireLaser];
    
}

#pragma mark acceleromter actions

- (void)startMonitoringAcceleration
{
    if (_motionManager.accelerometerAvailable)
    {
        [_motionManager startAccelerometerUpdates];
        NSLog(@"accelerometer updates on...");
    }
}

- (void)stopMonitoringAcceleration
{
    if (_motionManager.accelerometerAvailable && _motionManager.accelerometerActive)
    {
        [_motionManager stopAccelerometerUpdates];
        NSLog(@"accelerometer updates off...");
    }
}

- (void)updateShipPositionFromMotionManager
{
    CMAccelerometerData* data = _motionManager.accelerometerData;
    if (fabs(data.acceleration.x) > 0.3)
    {
        [_ship.physicsBody applyForce:CGVectorMake(0.0, 45.0 * data.acceleration.x)];
    }
}

#pragma mark End Game
- (void)endTheScene:(EndReason)endReason
{
    if (_gameOver)
    {
        return;
    }
    
    [self removeAllActions];
    [self stopMonitoringAcceleration];
    _ship.hidden = YES;
    _gameOver = YES;
    
    NSString *message;
    if (endReason == kEndReasonWin)
    {
        message = @"You win!";
    }
    else if (endReason == kEndReasonLose)
    {
        message = @"You lost!";
    }
    
    SKLabelNode *label;
    SKAction *labelScaleAction = [SKAction scaleTo:1.0 duration:0.5];
    
    label = [self CreateLabelWithName:@"winLoseLabel"
                             WithText:message
                            WithColor:[SKColor yellowColor]
                             WithSize:15];
    label.scale = 0.1;
    label.position = CGPointMake(self.frame.size.width/2, self.frame.size.height * 0.6);
    [label runAction:labelScaleAction];
    [self addChild:label];
    
    label = [self CreateLabelWithName:@"restartLabel"
                             WithText:@"Play Again?"
                            WithColor:[SKColor yellowColor]
                             WithSize:15];

    label.scale = 0.5;
    label.position = CGPointMake(self.frame.size.width/2, self.frame.size.height * 0.4);
    [label runAction:labelScaleAction];
    [self addChild:label];
}

#pragma mark Update gamescene

-(void)update:(NSTimeInterval)currentTime
{
    /* Called before each frame is rendered */
    double curTime = CACurrentMediaTime();

    //Update background (parallax) position
    [_parallaxSpaceDust update:currentTime];
    [_parallaxNodeBackgrounds update:currentTime];
    
    //update ship position
    [self updateShipPositionFromMotionManager];
    
    //spawn new astroid
    [self SpawnNewAstroid:curTime];
    
//    //check for collsions
//    if (!_gameOver)
//    {
//        [self CheckForCollisions:curTime];
//    }
}

-(void)UpdateScore
{
    _score += [self randomValueBetween:1 andValue:25];
    [self rewardBonusBomb];
    [self UpdateScoreLabel];
}

-(void)rewardBonusBomb
{
   // TODO refactor needed
    if (_score > 100 && _score < 200)
    {
        _bombs++;
    }
    else if (_score > 200 && _score < 400)
    {
        _bombs++;
    }
    else if (_score > 400 && _score < 600)
    {
        _bombs++;
    }
    else if (_score > 600 && _score < 800)
    {
        _bombs++;
    }
    else if (_score > 800 && _score < 1000)
    {
        _bombs++;
    }
    else if (_score > 1000 && _score < 2000)
    {
        _bombs++;
    }
    
}

#pragma mark spawn objects

-(void) LoadSpaceShip
{
    _ship = [SKSpriteNode spriteNodeWithImageNamed:@"SpaceFlier_med_1.png"];
	[_ship setXScale:0.5];
    [_ship setYScale:0.5];
    _ship.position = CGPointMake(self.frame.size.width * 0.1, CGRectGetMidY(self.frame));
    
    CGFloat offsetX = _ship.frame.size.width * _ship.anchorPoint.x;
    CGFloat offsetY = _ship.frame.size.height * _ship.anchorPoint.y;
  
    //TODO refactor this to a max 12 point vector
    CGMutablePathRef path = CGPathCreateMutable();
    CGPathMoveToPoint(path, NULL, 32 - offsetX, 9 - offsetY);
    CGPathAddLineToPoint(path, NULL, 14 - offsetX, 16 - offsetY);
    CGPathAddLineToPoint(path, NULL, 9 - offsetX, 17 - offsetY);
    CGPathAddLineToPoint(path, NULL, 6 - offsetX, 17 - offsetY);
    CGPathAddLineToPoint(path, NULL, 4 - offsetX, 15 - offsetY);
    CGPathAddLineToPoint(path, NULL, 1 - offsetX, 14 - offsetY);
    CGPathAddLineToPoint(path, NULL, 4 - offsetX, 1 - offsetY);
    CGPathAddLineToPoint(path, NULL, 14 - offsetX, 3 - offsetY);
    CGPathAddLineToPoint(path, NULL, 23 - offsetX, -1 - offsetY);
    CGPathAddLineToPoint(path, NULL, 32 - offsetX, -1 - offsetY);
    CGPathCloseSubpath(path);
    
    
    _ship.physicsBody = [SKPhysicsBody bodyWithPolygonFromPath:path];
    _ship.physicsBody.dynamic = YES;
    _ship.physicsBody.affectedByGravity = NO;
    _ship.physicsBody.mass = 1.0;
    _ship.physicsBody.contactTestBitMask = enemyCategory;
    _ship.physicsBody.categoryBitMask = shipCategory;
    _ship.physicsBody.collisionBitMask = 0;
    CGPathRelease(path);
    
    [self addChild:_ship];
    
}

- (SKEmitterNode *)loadExplosionEmitterNode:(NSString *)emitterFileName atPosition:(CGPoint)position withSize:(CGSize)size
{
    NSString *emitterPath = [[NSBundle mainBundle] pathForResource:emitterFileName ofType:@"sks"];
    SKEmitterNode *emitterNode = [NSKeyedUnarchiver unarchiveObjectWithFile:emitterPath];
  
    emitterNode.position = position;
    emitterNode.particleSize = size;
    
    return emitterNode;
}

- (SKEmitterNode *)loadStarEmitterNode:(NSString *)emitterFileName
{
    NSString *emitterPath = [[NSBundle mainBundle] pathForResource:emitterFileName ofType:@"sks"];
    SKEmitterNode *emitterNode = [NSKeyedUnarchiver unarchiveObjectWithFile:emitterPath];
    
    emitterNode.particlePosition = CGPointMake(self.size.width/2.0, self.size.height/2.0);
    emitterNode.particlePositionRange = CGVectorMake(self.size.width+100, self.size.height);
    
    return emitterNode;
}

- (void) SpawnNewAstroid:(double)CurrentGameTime
{
    if (CurrentGameTime > _nextAsteroidSpawn)
    {
        //NSLog(@"spawning new asteroid");
        float randSecs = [self randomValueBetween:0.20 andValue:1.0];
        _nextAsteroidSpawn = randSecs + CurrentGameTime;
        
        float randY = [self randomValueBetween:0.0 andValue:self.frame.size.height];
        float randDuration = [self randomValueBetween:2.0 andValue:10.0];
        
        SKSpriteNode *asteroid = [SKSpriteNode spriteNodeWithImageNamed:@"asteroid"];
        [asteroid setXScale:0.3];
        [asteroid setYScale:0.3];

        asteroid.physicsBody = [SKPhysicsBody bodyWithRectangleOfSize:asteroid.size];
        asteroid.physicsBody.dynamic = YES;
        asteroid.physicsBody.categoryBitMask = enemyCategory;
        asteroid.physicsBody.contactTestBitMask = laserCategory;
        asteroid.physicsBody.collisionBitMask = 0;
        asteroid.position = CGPointMake(self.frame.size.width+asteroid.size.width/2, randY);
        
        CGPoint toLocation = CGPointMake(-self.frame.size.width-asteroid.size.width, randY);
        
        SKAction *moveAction = [SKAction moveTo:toLocation duration:randDuration];
        SKAction *moveAsteroidActionWithDone = [SKAction sequence:@[moveAction, [SKAction removeFromParent]]];
        [asteroid runAction:moveAsteroidActionWithDone withKey:@"asteroidMoving"];
        
        [self addChild:asteroid];
    }
}

-(void)FireLaser
{
    SKSpriteNode *shipLaser = [SKSpriteNode spriteNodeWithImageNamed:@"laserbeam_blue"];
    
    shipLaser.physicsBody = [SKPhysicsBody bodyWithRectangleOfSize:shipLaser.size];
    shipLaser.physicsBody.dynamic = NO;
    shipLaser.physicsBody.categoryBitMask = laserCategory;
    shipLaser.physicsBody.contactTestBitMask = enemyCategory;
    shipLaser.physicsBody.collisionBitMask = 0;

    shipLaser.position = CGPointMake(_ship.position.x+shipLaser.size.width/2,_ship.position.y-7.3);
    
    shipLaser.zPosition = 1;
    
    shipLaser.xScale = 0.8;
    shipLaser.yScale = 0.8;
    
    
    CGPoint location = CGPointMake(self.frame.size.width, _ship.position.y);

    SKAction *laserFireSoundAction = [SKAction playSoundFileNamed:@"laser_ship.caf" waitForCompletion:NO];
    SKAction *laserMoveAction = [SKAction moveTo:location duration:0.5];
    SKAction *moveLaserActionWithDone = [SKAction sequence:@[laserFireSoundAction, laserMoveAction, [SKAction removeFromParent]]];
    [shipLaser runAction:moveLaserActionWithDone withKey:@"laserFired"];

    [self addChild:shipLaser];
    
}

#pragma mark Collision detection


-(void)didBeginContact:(SKPhysicsContact *)contact
{
    SKPhysicsBody *firstBody;
    SKPhysicsBody *secondBody;
    if (contact.bodyA.categoryBitMask < contact.bodyB.categoryBitMask)
    {
        firstBody = contact.bodyA;
        secondBody = contact.bodyB;
    }
    else
    {
        firstBody = contact.bodyB;
        secondBody = contact.bodyA;
    }
    
    if ((firstBody.categoryBitMask & laserCategory) != 0)
    {
        SKNode *projectile = (contact.bodyA.categoryBitMask & laserCategory) ? contact.bodyA.node : contact.bodyB.node;
        SKNode *enemy = (contact.bodyA.categoryBitMask & laserCategory) ? contact.bodyB.node : contact.bodyA.node;
        
        
        
        [self addChild:[self loadExplosionEmitterNode:@"Explosion" atPosition:enemy.position withSize:enemy.frame.size]];
       
        SKAction *asteroidExplosionSound = [SKAction playSoundFileNamed:@"explosion_small.caf" waitForCompletion:NO];
        
        [projectile runAction:[SKAction removeFromParent]];
        [enemy runAction:[SKAction sequence:@[asteroidExplosionSound, [SKAction removeFromParent]]]];
        
        [self UpdateScore];
    }
    
    //TODO contact with spaceship
    
    
    
    
}
 
 
/*

-(void)CheckForCollisions:(double)CurrentGameTime
{
    //check for laser collision with asteroid
    for (SKSpriteNode *asteroid in _asteroids)
    {
        if (asteroid.hidden)
        {
            continue;
        }
        for (SKSpriteNode *shipLaser in _shipLasers)
        {
            if (shipLaser.hidden)
            {
                continue;
            }
            
            if ([shipLaser intersectsNode:asteroid])
            {
                shipLaser.hidden = YES;
                asteroid.hidden = YES;
                
                SKAction *asteroidExplosionSound = [SKAction playSoundFileNamed:@"explosion_small.caf" waitForCompletion:NO];
                [asteroid runAction:asteroidExplosionSound];

                [self UpdateScore];
                
                NSLog(@"you just destroyed an asteroid");
                continue;
            }
        }
        
        if ([_ship intersectsNode:asteroid])
        {
            asteroid.hidden = YES;
            SKAction *blink = [SKAction sequence:@[[SKAction fadeOutWithDuration:0.1],
                                                   [SKAction fadeInWithDuration:0.1]]];
            SKAction *blinkForTime = [SKAction repeatAction:blink count:4];
            SKAction *shipExplosionSound = [SKAction playSoundFileNamed:@"explosion_large.caf" waitForCompletion:NO];
            [_ship runAction:[SKAction sequence:@[shipExplosionSound,blinkForTime]]];
            --_lives;
            [self UpdateLivesLabel];
            
            NSLog(@"your ship has been hit!");
        }
        
        // Add at end of update loop
        if (_lives <= 0)
        {
            NSLog(@"you lose...");
            [self endTheScene:kEndReasonLose];
        }
        else if (CurrentGameTime >= _gameOverTime)
        {
            NSLog(@"you won...");
            [self endTheScene:kEndReasonWin];
        }
    }
}
*/
#pragma mark setup the hud and update it

-(void)setupHud
{
	SKLabelNode *label = [self CreateLabelWithName: kScoreHudName
									WithText:[NSString stringWithFormat:@"Score: %04u", 0] 
								   WithColor:[SKColor greenColor] 
									WithSize:15];
    label.position = CGPointMake(20 + label.frame.size.width/2, self.size.height - (20 + label.frame.size.height/2));
    [self addChild:label];

    label = [self CreateLabelWithName:kLivesHudName
                             WithText:[NSString stringWithFormat:@"Lives: %d", _lives]
                            WithColor:[SKColor redColor]
                             WithSize:15];
    label.position = CGPointMake(self.size.width - label.frame.size.width/2 - 20, self.size.height - (20 + label.frame.size.height/2));
    [self addChild:label];
    
    //    SKLabelNode* bombLabel = [SKLabelNode labelNodeWithFontNamed:@"Futura-CondensedMedium"];
    //    bombLabel.name = kBombHudName;
    //    bombLabel.fontSize = 20;
    //    bombLabel.fontColor = [SKColor greenColor];
    //    bombLabel.text = [NSString stringWithFormat:@"Bombs: %d", 3];
    //    bombLabel.position = CGPointMake(scoreLabel.frame.size.width + self.size.width/3 + bombLabel.frame.size.width/2, self.size.height - (20 + bombLabel.frame.size.height/2));
    //    [self addChild:bombLabel];
    
}

-(SKLabelNode *)CreateLabelWithName:(NSString *)name WithText:(NSString *)text WithColor:(SKColor *)color WithSize:(int)size
{
	SKLabelNode* labelNode = [SKLabelNode labelNodeWithFontNamed:@"Future-CondensedMedium"];
	labelNode.name = name;
	labelNode.fontSize = size;
    labelNode.fontColor = color;
    labelNode.text = text;
    
	return labelNode;
}

-(void)UpdateHud
{
    [self UpdateLivesLabel];
    [self UpdateScoreLabel];
    [self UpdateBombsLabel];
}

-(void)UpdateLivesLabel
{
    SKLabelNode* label = (SKLabelNode*)[self childNodeWithName:kLivesHudName];
    label.text = [NSString stringWithFormat:@"Lives: %d", _lives];
}

-(void)UpdateBombsLabel
{
    SKLabelNode* label = (SKLabelNode*)[self childNodeWithName:kBombHudName];
    label.text = [NSString stringWithFormat:@"Bombs: %d", _bombs];
}

-(void)UpdateScoreLabel
{
    SKLabelNode* label = (SKLabelNode*)[self childNodeWithName:kScoreHudName];
    label.text = [NSString stringWithFormat:@"Score: %04u", _score];
}

#pragma mark Backgroudmusic

- (void)startBackgroundMusic
{
    NSError *err;
    NSURL *file = [NSURL fileURLWithPath:[[NSBundle mainBundle] pathForResource:@"SpaceGame.caf" ofType:nil]];
    _backgroundAudioPlayer = [[AVAudioPlayer alloc] initWithContentsOfURL:file error:&err];
    if (err)
    {
        NSLog(@"error in audio play %@",[err userInfo]);
        return;
    }
    [_backgroundAudioPlayer prepareToPlay];
    
    // this will play the music infinitely
    _backgroundAudioPlayer.numberOfLoops = -1;
    [_backgroundAudioPlayer setVolume:1.0];
    [_backgroundAudioPlayer play];
}

#pragma mark general helpers
- (float)randomValueBetween:(float)low andValue:(float)high
{
    return (((float) arc4random() / 0xFFFFFFFFu) * (high - low)) + low;
}

#pragma mark Bomb aways
-(void)BombDropped
{
    --_bombs;
//    for (SKSpriteNode *asteroid in _asteroids)
//    {
//        asteroid.hidden = YES;
//        
//        SKAction *asteroidExplosionSound = [SKAction playSoundFileNamed:@"explosion_small.caf" waitForCompletion:NO];
//        [asteroid runAction:asteroidExplosionSound];
//        _score+= [self randomValueBetween:1 andValue:26];
//        [self UpdateScore];
//        
//        NSLog(@"you just destroyed an asteroid");
//        continue;
//    }
    [self UpdateBombsLabel];
    
}

@end






















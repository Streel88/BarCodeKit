//
//  BCKCode.m
//  BarCodeKit
//
//  Created by Oliver Drobnik on 8/9/13.
//  Copyright (c) 2013 Oliver Drobnik. All rights reserved.
//

#import "BCKCode.h"
#import "BarCodeKit.h"

// options
NSString * const BCKCodeDrawingBarScaleOption = @"BCKCodeDrawingBarScale";
NSString * const BCKCodeDrawingPrintCaptionOption = @"BCKCodeDrawingPrintCaption";
NSString * const BCKCodeDrawingMarkerBarsOverlapCaptionPercentOption = @"BCKCodeDrawingMarkerBarsOverlapCaptionPercent";
NSString * const BCKCodeDrawingFillEmptyQuietZonesOption = @"BCKCodeDrawingFillEmptyQuietZones";
NSString * const BCKCodeDrawingDebugOption = @"BCKCodeDrawingDebug";



@implementation BCKCode

- (instancetype)initWithContent:(NSString *)content
{
	self = [super init];
	
	if (self)
	{
		_content = [content copy];
	}
	
	return self;
}

- (NSString *)bitString
{
	NSMutableString *tmpString = [NSMutableString string];
	
	for (BCKEANCodeCharacter *oneCharacter in [self codeCharacters])
	{
		[tmpString appendString:[oneCharacter bitString]];
	}
	
	return tmpString;
}

- (NSString *)description
{
	return [NSString stringWithFormat:@"<%@ content='%@'>", NSStringFromClass([self class]), [self bitString]];
}

#pragma mark - Helper Methods

// returns the actually displayed left quiet zone text based on the options
- (NSString *)_leftQuietZoneDisplayTextWithOptions:(NSDictionary *)options
{
	NSString *leftQuietZoneText = [self captionTextForZone:BCKCodeDrawingCaptionLeftQuietZone];
	
	if ([[options objectForKey:BCKCodeDrawingFillEmptyQuietZonesOption] boolValue])
	{
		if (!leftQuietZoneText)
		{
			leftQuietZoneText = @"<";
		}
	}
	
	return leftQuietZoneText;
}

// returns the actually displayed right quiet zone text based on the options
- (NSString *)_rightQuietZoneDisplayTextWithOptions:(NSDictionary *)options
{
	NSString *rightQuietZoneText = [self captionTextForZone:BCKCodeDrawingCaptionRightQuietZone];
	
	if ([[options objectForKey:BCKCodeDrawingFillEmptyQuietZonesOption] boolValue])
	{
		if (!rightQuietZoneText)
		{
			rightQuietZoneText = @">";
		}
	}
	
	return rightQuietZoneText;
}


// returns the actually displayed left caption zone text based on the options
- (NSString *)_leftCaptionZoneDisplayTextWithOptions:(NSDictionary *)options
{
	if (![self _shouldDrawCaptionFromOptions:options])
	{
		return nil;
	}
	
	NSMutableString *tmpString = [NSMutableString string];
	
	// aggregate digits before marker
	[[self codeCharacters] enumerateObjectsUsingBlock:^(BCKEANCodeCharacter *character, NSUInteger charIndex, BOOL *stop) {
		
		if ([character isKindOfClass:[BCKEANMiddleMarkerCodeCharacter class]])
		{
			*stop = YES;
		}
		else if ([character isKindOfClass:[BCKEANDigitCodeCharacter class]])
		{
			BCKEANDigitCodeCharacter *digitChar = (BCKEANDigitCodeCharacter *)character;
			[tmpString appendFormat:@"%d", [digitChar digit]];
		}
	}];
	
	if ([tmpString length])
	{
		return [tmpString copy];
	}
	
	return nil;
}


// returns the actually displayed left caption zone text based on the options
- (NSString *)_rightCaptionZoneDisplayTextWithOptions:(NSDictionary *)options
{
	if (![self _shouldDrawCaptionFromOptions:options])
	{
		return nil;
	}
	
	NSMutableString *tmpString = [NSMutableString string];
	
	__block BOOL metMiddleMarker = NO;
	
	// aggregate digits after marker
	[[self codeCharacters] enumerateObjectsUsingBlock:^(BCKEANCodeCharacter *character, NSUInteger charIndex, BOOL *stop) {
		
		if ([character isKindOfClass:[BCKEANMiddleMarkerCodeCharacter class]])
		{
			metMiddleMarker = YES;
		}
		else if ([character isKindOfClass:[BCKEANDigitCodeCharacter class]])
		{
			if (metMiddleMarker)
			{
				BCKEANDigitCodeCharacter *digitChar = (BCKEANDigitCodeCharacter *)character;
				[tmpString appendFormat:@"%d", [digitChar digit]];
			}
		}
	}];
	
	if ([tmpString length])
	{
		return [tmpString copy];
	}
	
	return nil;
}

- (CGFloat)_horizontalQuietZoneWidthWithOptions:(NSDictionary *)options
{
	return ([self horizontalQuietZoneWidth]-1) * [self _barScaleFromOptions:options];
}

- (CGFloat)_leftCaptionZoneWidthWithOptions:(NSDictionary *)options
{
	__block NSUInteger bitsBeforeMiddle = 0;
	
	// aggregate digits before marker
	[[self codeCharacters] enumerateObjectsUsingBlock:^(BCKEANCodeCharacter *character, NSUInteger charIndex, BOOL *stop) {
		
		if ([character isKindOfClass:[BCKEANMiddleMarkerCodeCharacter class]])
		{
			*stop = YES;
		}
		else if ([character isKindOfClass:[BCKEANDigitCodeCharacter class]])
		{
			bitsBeforeMiddle += [[character bitString] length];
		}
	}];
	
	if (bitsBeforeMiddle>0)
	{
		bitsBeforeMiddle -= 2; // to space text away from width
	}
	
	return bitsBeforeMiddle * [self _barScaleFromOptions:options];
}

- (CGFloat)_rightCaptionZoneWidthWithOptions:(NSDictionary *)options
{
	__block NSUInteger bitsAfterMiddle = 0;
	__block BOOL metMiddleMarker = NO;
	
	// aggregate digits before marker
	[[self codeCharacters] enumerateObjectsUsingBlock:^(BCKEANCodeCharacter *character, NSUInteger charIndex, BOOL *stop) {
		
		if ([character isKindOfClass:[BCKEANMiddleMarkerCodeCharacter class]])
		{
			metMiddleMarker = YES;
		}
		else if ([character isKindOfClass:[BCKEANDigitCodeCharacter class]])
		{
			if (metMiddleMarker)
			{
				bitsAfterMiddle += [[character bitString] length];
			}
		}
	}];
	
	if (bitsAfterMiddle>0)
	{
		bitsAfterMiddle -= 2; // to space text away from width
	}
	
	return bitsAfterMiddle * [self _barScaleFromOptions:options];
}



- (CGFloat)_captionFontSizeWithOptions:(NSDictionary *)options
{
	NSString *leftQuietZoneText = [self _leftQuietZoneDisplayTextWithOptions:options];
	NSString *rightQuietZoneText = [self _rightQuietZoneDisplayTextWithOptions:options];
	
	NSString *leftDigits = [self _leftCaptionZoneDisplayTextWithOptions:options];
	NSString *rightDigits = [self _rightCaptionZoneDisplayTextWithOptions:options];
	
	CGFloat optimalCaptionFontSize = CGFLOAT_MAX;
	
	if ([leftQuietZoneText length])
	{
		optimalCaptionFontSize = MIN(optimalCaptionFontSize, [self _optimalFontSizeToFitText:leftQuietZoneText insideWidth:[self _horizontalQuietZoneWidthWithOptions:options]]);
	}
	
	if ([leftDigits length])
	{
		optimalCaptionFontSize = MIN(optimalCaptionFontSize, [self _optimalFontSizeToFitText:leftDigits insideWidth:[self _leftCaptionZoneWidthWithOptions:options]]);
	}
	
	if ([rightDigits length])
	{
		optimalCaptionFontSize = MIN(optimalCaptionFontSize, [self _optimalFontSizeToFitText:rightDigits insideWidth:[self _rightCaptionZoneWidthWithOptions:options]]);
	}
	
	if ([rightQuietZoneText length])
	{
		optimalCaptionFontSize = MIN(optimalCaptionFontSize, [self _optimalFontSizeToFitText:rightQuietZoneText insideWidth:[self _horizontalQuietZoneWidthWithOptions:options]]);
	}
	
	return optimalCaptionFontSize;
}

- (UIFont *)_captionFontWithSize:(CGFloat)fontSize
{
	UIFont *font = [UIFont fontWithName:@"OCRB" size:fontSize];
	
	if (!font)
	{
		font = [UIFont systemFontOfSize:fontSize];
	}
	
	return font;
}

- (CGFloat)_optimalFontSizeToFitText:(NSString *)text insideWidth:(CGFloat)width
{
	NSMutableParagraphStyle *paragraphStyle = [[NSMutableParagraphStyle alloc] init];
	paragraphStyle.alignment = NSTextAlignmentCenter;
	
	CGFloat fontSize = 1;
	
	do
	{
		UIFont *font = [self _captionFontWithSize:fontSize];
		
		NSDictionary *attributes = @{NSFontAttributeName:font, NSParagraphStyleAttributeName:paragraphStyle};
		
		CGSize neededSize = [text sizeWithAttributes:attributes];
		
		if (neededSize.width >= width)
		{
			break;
		}
		
		fontSize++;
	}
	while (1);
	
	return fontSize;
}

- (CGFloat)_barScaleFromOptions:(NSDictionary *)options
{
	NSNumber *barScaleNum = [options objectForKey:BCKCodeDrawingBarScaleOption];
	
	if (barScaleNum)
	{
		return [barScaleNum floatValue];
	}
	else
	{
		return 1;  // default
	}
}

- (BOOL)_shouldDrawCaptionFromOptions:(NSDictionary *)options
{
	NSNumber *num = [options objectForKey:BCKCodeDrawingPrintCaptionOption];
	
	if (num)
	{
		return [num boolValue];
	}
	else
	{
		return 1;  // default
	}
}

- (CGFloat)_markerBarCaptionOverlapFromOptions:(NSDictionary *)options
{
	NSNumber *num = [options objectForKey:BCKCodeDrawingMarkerBarsOverlapCaptionPercentOption];
	
	if (num)
	{
		return [num floatValue];
	}
	
	return 1; // default
}

- (BOOL)markerBarsCanOverlapBottomCaption
{
	return YES;
}

#pragma mark - Subclassing Methods

- (NSUInteger)horizontalQuietZoneWidth
{
	return 0;
}

- (NSArray *)codeCharacters
{
	return nil;
}

- (NSString *)captionTextForZone:(BCKCodeDrawingCaption)captionZone
{
	return nil;
}

- (CGFloat)aspectRatio
{
	return 1;
}

- (CGFloat)fixedHeight
{
	return 0;
}

#pragma mark - Drawing

- (void)_drawCaptionText:(NSString *)text fontSize:(CGFloat)fontSize inRect:(CGRect)rect context:(CGContextRef)context
{
	if (![text length])
	{
		return;
	}
	
	NSMutableParagraphStyle *paragraphStyle = [[NSMutableParagraphStyle alloc] init];
	paragraphStyle.alignment = NSTextAlignmentCenter;
	
	UIFont *font =[self _captionFontWithSize:fontSize];
	NSDictionary *attributes = @{NSFontAttributeName:font, NSParagraphStyleAttributeName:paragraphStyle};
	
	CGSize leftSize = [text sizeWithAttributes:attributes];
	[[UIColor blackColor] setFill];
	
	[text drawAtPoint:CGPointMake(CGRectGetMidX(rect)-leftSize.width/2.0f, CGRectGetMaxY(rect)-font.ascender-0.5) withAttributes:attributes];
}

- (CGSize)sizeWithRenderOptions:(NSDictionary *)options
{
	CGFloat barScale = [self _barScaleFromOptions:options];
	
	NSUInteger horizontalQuietZoneWidth = [self horizontalQuietZoneWidth];
	
	NSString *bitString = [self bitString];
	NSUInteger length = [bitString length];
	
	
	CGSize size = CGSizeZero;
	size.width = (length + 2.0f * horizontalQuietZoneWidth) * barScale;
	
	CGFloat aspectRatio = [self aspectRatio];
	
	if (aspectRatio)
	{
		size.height = size.width / [self aspectRatio];
	}
	else
	{
		size.height = [self fixedHeight];
	}
	
	return size;
}

- (void)renderInContext:(CGContextRef)context options:(NSDictionary *)options
{
	CGContextSaveGState(context);
	
	CGFloat barScale = [self _barScaleFromOptions:options];
	CGSize size = [self sizeWithRenderOptions:options];
	
	NSString *leftQuietZoneText = [self _leftQuietZoneDisplayTextWithOptions:options];
	NSString *leftDigits = [self _leftCaptionZoneDisplayTextWithOptions:options];
	NSString *rightDigits = [self _rightCaptionZoneDisplayTextWithOptions:options];
	NSString *rightQuietZoneText = [self _rightQuietZoneDisplayTextWithOptions:options];
	
	CGFloat captionHeight = 0;
	CGFloat optimalCaptionFontSize = 0;
	CGRect bottomCaptionRegion = CGRectMake(0, size.height, size.width, 0);
	
	// determine height of caption if needed
	if ([self _shouldDrawCaptionFromOptions:options])
	{
		optimalCaptionFontSize = [self _captionFontSizeWithOptions:options];
		UIFont *font = [self _captionFontWithSize:optimalCaptionFontSize];
		captionHeight = ceilf(font.ascender);
		
		bottomCaptionRegion = CGRectMake(0, size.height-captionHeight - barScale, size.width, captionHeight + barScale);
	}
	
	// determine bar lengths, bars for digits are usually shorter than bars for markers
	CGFloat captionOverlap = [self _markerBarCaptionOverlapFromOptions:options];
	CGFloat digitBarLength = CGRectGetMinY(bottomCaptionRegion);
	CGFloat markerBarLength = CGRectGetMinY(bottomCaptionRegion) + captionOverlap * bottomCaptionRegion.size.height;
	
	__block NSUInteger drawnBitIndex = 0;
	__block BOOL metMiddleMarker = NO;
	__block CGRect leftQuietZoneNumberFrame = CGRectZero;
	__block CGRect leftNumberFrame = CGRectNull;
	__block CGRect rightNumberFrame = CGRectNull;
	__block CGRect frameBetweenEndMarkers = CGRectNull;
	__block CGRect rightQuietZoneNumberFrame = CGRectZero;
	NSUInteger horizontalQuietZoneWidth = [self horizontalQuietZoneWidth];
	BOOL useOverlap = [self markerBarsCanOverlapBottomCaption];
	
	// enumerate the code characters
	[[self codeCharacters] enumerateObjectsUsingBlock:^(BCKEANCodeCharacter *character, NSUInteger charIndex, BOOL *stop) {
		
		// bar length is different for markers and digits
		CGFloat barLength = digitBarLength;
		
		if (useOverlap && [character isMarkerCharacter])
		{
			barLength = markerBarLength;
		}
		
		__block CGRect characterRect = CGRectNull;
		
		// walk through the bits of the character
		[character enumerateBitsUsingBlock:^(BOOL isBar, NSUInteger idx, BOOL *stop) {
			
			CGFloat x = (drawnBitIndex + horizontalQuietZoneWidth) * barScale;
			CGRect barRect = CGRectMake(x, 0, barScale, barLength);
			
			if (CGRectIsNull(characterRect))
			{
				characterRect = barRect;
			}
			else
			{
				characterRect = CGRectUnion(characterRect, barRect);
			}
			
			if (isBar)
			{
				CGContextAddRect(context, barRect);
			}
			
			drawnBitIndex++;
		}];
		
		// add the character rect to the appropriate frame
		
		if ([character isKindOfClass:[BCKEANMiddleMarkerCodeCharacter class]])
		{
			metMiddleMarker = YES;
		}
		else if ([character isKindOfClass:[BCKEANEndMarkerCodeCharacter class]] || [character isKindOfClass:[BCKCode39EndMarkerCodeCharacter class]])
		{
			if (CGRectIsEmpty(leftQuietZoneNumberFrame))
			{
				// right marker
				leftQuietZoneNumberFrame = CGRectMake(0, 0, characterRect.origin.x, size.height);
			}
		}
		else if ([character isKindOfClass:[BCKEANDigitCodeCharacter class]])
		{
			if (metMiddleMarker)
			{
				if (CGRectIsNull(rightNumberFrame))
				{
					// first digit in right number frame
					rightNumberFrame = CGRectMake(characterRect.origin.x, characterRect.origin.y, characterRect.size.width, size.height);
				}
				else
				{
					// add it to existing right number frame
					rightNumberFrame = CGRectUnion(characterRect, rightNumberFrame);
				}
			}
			else
			{
				if (CGRectIsNull(leftNumberFrame))
				{
					// first digit in left number frame
					leftNumberFrame = CGRectMake(characterRect.origin.x, characterRect.origin.y, characterRect.size.width, size.height);
				}
				else
				{
					// add it to existing left number frame
					leftNumberFrame = CGRectUnion(characterRect, leftNumberFrame);
				}
			}
		}
		
		if (![character isMarkerCharacter])
		{
			if (CGRectIsNull(frameBetweenEndMarkers))
			{
				frameBetweenEndMarkers = CGRectMake(characterRect.origin.x, characterRect.origin.y, characterRect.size.width, size.height);
			}
			else
			{
				frameBetweenEndMarkers = CGRectUnion(frameBetweenEndMarkers, characterRect);
			}
		}
			
		
		// moving right marker 
		CGFloat x = CGRectGetMaxX(characterRect);
		rightQuietZoneNumberFrame = CGRectMake(x, 0, size.width - x, size.height);
	}];
	
	// paint all bars
	[[UIColor blackColor] setFill];
	CGContextFillPath(context);
	
	if ([self _shouldDrawCaptionFromOptions:options])
	{
		leftQuietZoneNumberFrame.size.width -= barScale;
		
		rightQuietZoneNumberFrame.origin.x += barScale;
		rightQuietZoneNumberFrame.size.width -= barScale;
		
		if (CGRectIsEmpty(leftNumberFrame))
		{
			// reduce the bar regions to the caption region
			leftQuietZoneNumberFrame = CGRectIntersection(bottomCaptionRegion, leftQuietZoneNumberFrame);
			rightQuietZoneNumberFrame = CGRectIntersection(bottomCaptionRegion, rightQuietZoneNumberFrame);
			frameBetweenEndMarkers = CGRectIntersection(bottomCaptionRegion, frameBetweenEndMarkers);

			// indent by 1 bar width
			frameBetweenEndMarkers.origin.x += barScale;
			frameBetweenEndMarkers.origin.y += barScale;
			frameBetweenEndMarkers.size.width -= 2.0*barScale;
			frameBetweenEndMarkers.size.height -= barScale;
			
			// DEBUG Option
			if ([[options objectForKey:BCKCodeDrawingDebugOption] boolValue])
			{
				[[UIColor colorWithRed:1 green:0 blue:0 alpha:0.6] set];
				CGContextFillRect(context, frameBetweenEndMarkers);
				[[UIColor colorWithRed:0 green:0 blue:1 alpha:0.6] set];
				CGContextFillRect(context, leftQuietZoneNumberFrame);
				[[UIColor colorWithRed:0 green:0 blue:1 alpha:0.6] set];
				CGContextFillRect(context, rightQuietZoneNumberFrame);
			}
			
			NSString *text = [self captionTextForZone:BCKCodeDrawingCaptionTextZone];
			[self _drawCaptionText:text fontSize:[self _captionFontSizeWithOptions:options] inRect:frameBetweenEndMarkers context:context];
		}
		else
		{
			// we have number zones
			
			// insure at least 1 bar width space between bars and caption
			leftNumberFrame.origin.x += barScale;
			leftNumberFrame.size.width -= barScale;
			
			rightNumberFrame.size.width -= barScale;
			
			// reduce the bar regions to the caption region
			leftNumberFrame = CGRectIntersection(bottomCaptionRegion, leftNumberFrame);
			rightNumberFrame = CGRectIntersection(bottomCaptionRegion, rightNumberFrame);
			leftQuietZoneNumberFrame = CGRectIntersection(bottomCaptionRegion, leftQuietZoneNumberFrame);
			rightQuietZoneNumberFrame = CGRectIntersection(bottomCaptionRegion, rightQuietZoneNumberFrame);
			
			// insure at least 1 bar width space between bars and caption
			leftNumberFrame.origin.y += barScale;
			leftNumberFrame.size.height -= barScale;
			
			rightNumberFrame.origin.y += barScale;
			rightNumberFrame.size.height -= barScale;
			
			leftQuietZoneNumberFrame.origin.y += barScale;
			leftQuietZoneNumberFrame.size.height -= barScale;
			
			rightQuietZoneNumberFrame.origin.y += barScale;
			rightQuietZoneNumberFrame.size.height -= barScale;
			
			
			// DEBUG Option
			if ([[options objectForKey:BCKCodeDrawingDebugOption] boolValue])
			{
				[[UIColor colorWithRed:1 green:0 blue:0 alpha:0.6] set];
				CGContextFillRect(context, leftNumberFrame);
				[[UIColor colorWithRed:0 green:1 blue:0 alpha:0.6] set];
				CGContextFillRect(context, rightNumberFrame);
				[[UIColor colorWithRed:0 green:0 blue:1 alpha:0.6] set];
				CGContextFillRect(context, leftQuietZoneNumberFrame);
				[[UIColor colorWithRed:0 green:0 blue:1 alpha:0.6] set];
				CGContextFillRect(context, rightQuietZoneNumberFrame);
			}
			
			// Draw Captions
			
			[self _drawCaptionText:leftDigits fontSize:optimalCaptionFontSize inRect:leftNumberFrame context:context];
			[self _drawCaptionText:rightDigits fontSize:optimalCaptionFontSize inRect:rightNumberFrame context:context];
			
			if (leftQuietZoneText)
			{
				[self _drawCaptionText:leftQuietZoneText fontSize:optimalCaptionFontSize inRect:leftQuietZoneNumberFrame context:context];
			}
			
			if (rightQuietZoneText)
			{
				[self _drawCaptionText:rightQuietZoneText fontSize:optimalCaptionFontSize inRect:rightQuietZoneNumberFrame context:context];
			}
		}
	}
	
	CGContextRestoreGState(context);
}

@end
//
//  LFZoomingView.m
//  LFImagePickerController
//
//  Created by LamTsanFeng on 2017/3/16.
//  Copyright © 2017年 LamTsanFeng. All rights reserved.
//

#import "LFZoomingView.h"
#import "UIView+LFMEFrame.h"
#import "UIView+LFMECommon.h"
#import "UIImage+LFMECommon.h"

#import <AVFoundation/AVFoundation.h>

/** 编辑功能 */
#import "LFDataFilterImageView.h"
#import "LFDrawView.h"
#import "LFSplashView.h"
#import "LFStickerView.h"

NSString *const kLFZoomingViewData_draw = @"LFZoomingViewData_draw";
NSString *const kLFZoomingViewData_sticker = @"LFZoomingViewData_sticker";
NSString *const kLFZoomingViewData_splash = @"LFZoomingViewData_splash";
NSString *const kLFZoomingViewData_filter = @"LFZoomingViewData_filter";

@interface LFZoomingView ()

/** 原始坐标 */
@property (nonatomic, assign) CGRect originalRect;
/** 真实的图片尺寸 */
@property (nonatomic, assign) CGSize imageSize;

@property (nonatomic, weak) LFDataFilterImageView *imageView;

/** 绘画 */
@property (nonatomic, weak) LFDrawView *drawView;
/** 贴图 */
@property (nonatomic, weak) LFStickerView *stickerView;
/** 模糊（马赛克、高斯模糊） */
//@property (nonatomic, weak) LFSplashView *splashView;
/** 模糊 */
@property (nonatomic, weak) LFSplashView *splashView;

/** 代理 */
@property (nonatomic ,weak) id delegate;

/** 记录编辑层是否可控 */
@property (nonatomic, assign) BOOL editEnable;
@property (nonatomic, assign) BOOL drawViewEnable;
@property (nonatomic, assign) BOOL stickerViewEnable;
@property (nonatomic, assign) BOOL splashViewEnable;

@end

@implementation LFZoomingView

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        _originalRect = frame;
        [self customInit];
    }
    return self;
}

- (void)customInit
{
    self.backgroundColor = [UIColor clearColor];
    self.contentMode = UIViewContentModeScaleAspectFit;
    self.editEnable = YES;
    
    LFDataFilterImageView *imageView = [[LFDataFilterImageView alloc] initWithFrame:self.bounds];
    imageView.backgroundColor = [UIColor clearColor];
    imageView.contentMode = UIViewContentModeScaleAspectFit;
    [self addSubview:imageView];
    self.imageView = imageView;
    LFSplashView *splashView = [[LFSplashView alloc] initWithFrame:self.bounds];
    __weak typeof(self) weakSelf = self;
    splashView.splashColor = ^UIColor *(CGPoint point) {
//        return [weakSelf.imageView LFME_colorOfPoint:point];
        point.x = point.x/weakSelf.bounds.size.width*weakSelf.imageSize.width;
        point.y = point.y/weakSelf.bounds.size.height*weakSelf.imageSize.height;
        return [weakSelf.image colorAtPixel:point];
    };
    /** 默认不能涂抹 */
    splashView.userInteractionEnabled = NO;
    [self addSubview:splashView];
    self.splashView = splashView;
    
    /** 绘画 */
    LFDrawView *drawView = [[LFDrawView alloc] initWithFrame:self.bounds];
    /** 默认不能触发绘画 */
    drawView.userInteractionEnabled = NO;
    [self addSubview:drawView];
    self.drawView = drawView;
    
    /** 贴图 */
    LFStickerView *stickerView = [[LFStickerView alloc] initWithFrame:self.bounds];
    /** 禁止后，贴图将不能拖到，设计上，贴图是永远可以拖动的 */
//    stickerView.userInteractionEnabled = NO;
    [self addSubview:stickerView];
    self.stickerView = stickerView;
}

- (void)setImage:(UIImage *)image
{
    [self setImage:image durations:nil];
}

- (void)setImage:(UIImage *)image durations:(NSArray <NSNumber *> *)durations
{
    _image = image;
    if (image) {
        _imageSize = image.size;
        CGRect imageViewRect = AVMakeRectWithAspectRatioInsideRect(self.imageSize, self.originalRect);
        self.size = imageViewRect.size;
        
        /** 子控件更新 */
        [[self subviews] enumerateObjectsUsingBlock:^(__kindof UIView * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
            obj.frame = self.bounds;
        }];
    }
    
    /** 判断是否大图、长图之类的图片，暂时规定超出当前手机屏幕的n倍就是大图了 */
    CGFloat scale = 12.5f;
    BOOL isLongImage = MAX(self.imageSize.height/self.imageSize.width, self.imageSize.width/self.imageSize.height) > scale;
    if (image.images.count == 0 && (isLongImage || (self.imageSize.width > [UIScreen mainScreen].bounds.size.width * scale || self.imageSize.height > [UIScreen mainScreen].bounds.size.height * scale))) { // 长图UIView -> CATiledLayer
        self.imageView.contextType = LFContextTypeLargeImage;
    } else { //正常图UIView
        self.imageView.contextType = LFContextTypeDefault;
    }
    [self.imageView setImageByUIImage:image durations:durations];
}

- (void)setImageViewHidden:(BOOL)imageViewHidden
{
    self.imageView.hidden = imageViewHidden;
}

- (BOOL)isImageViewHidden
{
    return self.imageView.isHidden;
}

- (void)setMoveCenter:(BOOL (^)(CGRect))moveCenter
{
    _moveCenter = moveCenter;
    if (moveCenter) {
        _stickerView.moveCenter = moveCenter;
    } else {
        _stickerView.moveCenter = nil;
    }
}

#pragma mark - LFEditingProtocol

- (void)setEditDelegate:(id<LFPhotoEditDelegate>)editDelegate
{
    _delegate = editDelegate;
    /** 设置代理回调 */
    __weak typeof(self) weakSelf = self;
    
    if (_delegate) {
        /** 绘画 */
        _drawView.drawBegan = ^{
            if ([weakSelf.delegate respondsToSelector:@selector(lf_photoEditDrawBegan)]) {
                [weakSelf.delegate lf_photoEditDrawBegan];
            }
        };
        
        _drawView.drawEnded = ^{
            if ([weakSelf.delegate respondsToSelector:@selector(lf_photoEditDrawEnded)]) {
                [weakSelf.delegate lf_photoEditDrawEnded];
            }
        };
        
        /** 贴图 */
        _stickerView.tapEnded = ^(LFStickerItem *item, BOOL isActive) {
            if ([weakSelf.delegate respondsToSelector:@selector(lf_photoEditStickerDidSelectViewIsActive:)]) {
                [weakSelf.delegate lf_photoEditStickerDidSelectViewIsActive:isActive];
            }
        };
        
        /** 模糊 */
        _splashView.splashBegan = ^{
            if ([weakSelf.delegate respondsToSelector:@selector(lf_photoEditSplashBegan)]) {
                [weakSelf.delegate lf_photoEditSplashBegan];
            }
        };
        
        _splashView.splashEnded = ^{
            if ([weakSelf.delegate respondsToSelector:@selector(lf_photoEditSplashEnded)]) {
                [weakSelf.delegate lf_photoEditSplashEnded];
            }
        };
    } else {
        _drawView.drawBegan = nil;
        _drawView.drawEnded = nil;
        _stickerView.tapEnded = nil;
        _splashView.splashBegan = nil;
        _splashView.splashEnded = nil;
    }
    
}

- (id<LFPhotoEditDelegate>)editDelegate
{
    return _delegate;
}

/** 禁用其他功能 */
- (void)photoEditEnable:(BOOL)enable
{
    if (_editEnable != enable) {
        _editEnable = enable;
        if (enable) {
            _drawView.userInteractionEnabled = _drawViewEnable;
            _splashView.userInteractionEnabled = _splashViewEnable;
            _stickerView.userInteractionEnabled = _stickerViewEnable;
        } else {
            _drawViewEnable = _drawView.userInteractionEnabled;
            _splashViewEnable = _splashView.userInteractionEnabled;
            _stickerViewEnable = _stickerView.userInteractionEnabled;
            _drawView.userInteractionEnabled = NO;
            _splashView.userInteractionEnabled = NO;
            _stickerView.userInteractionEnabled = NO;
        }
    }
}

/** 显示视图 */
- (UIView *)displayView
{
    if (self.imageView.contentView) {
        return self.imageView;
    }
    return nil;
}

#pragma mark - 数据
- (NSDictionary *)photoEditData
{
    NSDictionary *drawData = _drawView.data;
    NSDictionary *stickerData = _stickerView.data;
    NSDictionary *splashData = _splashView.data;
    NSDictionary *filterData = _imageView.data;
    
    NSMutableDictionary *data = [@{} mutableCopy];
    if (drawData) [data setObject:drawData forKey:kLFZoomingViewData_draw];
    if (stickerData) [data setObject:stickerData forKey:kLFZoomingViewData_sticker];
    if (splashData) [data setObject:splashData forKey:kLFZoomingViewData_splash];
    if (filterData) [data setObject:filterData forKey:kLFZoomingViewData_filter];
    
    if (data.count) {
        return data;
    }
    return nil;
}

- (void)setPhotoEditData:(NSDictionary *)photoEditData
{
    _drawView.data = photoEditData[kLFZoomingViewData_draw];
    _stickerView.data = photoEditData[kLFZoomingViewData_sticker];
    _splashView.data = photoEditData[kLFZoomingViewData_splash];
    _imageView.data = photoEditData[kLFZoomingViewData_filter];
}

#pragma mark - 滤镜功能
/** 滤镜类型 */
- (void)changeFilterType:(NSInteger)cmType
{
    self.imageView.type = cmType;
}
/** 当前使用滤镜类型 */
- (NSInteger)getFilterType
{
    return self.imageView.type;
}
/** 获取滤镜图片 */
- (UIImage *)getFilterImage
{
    return [self.imageView renderedAnimatedUIImage];
}

#pragma mark - 绘画功能
/** 启用绘画功能 */
- (void)setDrawEnable:(BOOL)drawEnable
{
    _drawView.userInteractionEnabled = drawEnable;
}
- (BOOL)drawEnable
{
    return _drawView.userInteractionEnabled;
}
/** 正在绘画 */
- (BOOL)isDrawing
{
    return _drawView.isDrawing;
}

- (BOOL)drawCanUndo
{
    return _drawView.canUndo;
}
- (void)drawUndo
{
    [_drawView undo];
}
/** 设置绘画颜色 */
- (void)setDrawColor:(UIColor *)color
{
    _drawView.lineColor = color;
}

/** 设置绘画线粗 */
- (void)setDrawLineWidth:(CGFloat)lineWidth
{
    _drawView.lineWidth = lineWidth;
}

#pragma mark - 贴图功能
/** 贴图启用 */
- (BOOL)stickerEnable
{
    return [_stickerView isEnable];
}
/** 取消激活贴图 */
- (void)stickerDeactivated
{
    [LFStickerView LFStickerViewDeactivated];
}
/** 激活选中的贴图 */
- (void)activeSelectStickerView
{
    [_stickerView activeSelectStickerView];
}
/** 删除选中贴图 */
- (void)removeSelectStickerView
{
    [_stickerView removeSelectStickerView];
}
/** 屏幕缩放率 */
- (void)setScreenScale:(CGFloat)scale
{
    _stickerView.screenScale = scale;
}
/** 最小缩放率 默认0.2 */
- (void)setStickerMinScale:(CGFloat)stickerMinScale
{
    _stickerView.minScale = stickerMinScale;
}
- (CGFloat)stickerMinScale
{
    return _stickerView.minScale;
}
/** 最大缩放率 默认3.0 */
- (void)setStickerMaxScale:(CGFloat)stickerMaxScale
{
    _stickerView.maxScale = stickerMaxScale;
}
- (CGFloat)stickerMaxScale
{
    return _stickerView.maxScale;
}
/** 创建贴图 */
- (void)createSticker:(LFStickerItem *)item
{
    [_stickerView createStickerItem:item];
}
/** 获取选中贴图的内容 */
- (LFStickerItem *)getSelectSticker
{
    return [_stickerView getSelectStickerItem];
}
/** 更改选中贴图内容 */
- (void)changeSelectSticker:(LFStickerItem *)item
{
    [_stickerView changeSelectStickerItem:item];
}

#pragma mark - 模糊功能
/** 启用模糊功能 */
- (void)setSplashEnable:(BOOL)splashEnable
{
    _splashView.userInteractionEnabled = splashEnable;
}
- (BOOL)splashEnable
{
    return _splashView.userInteractionEnabled;
}
/** 正在模糊 */
- (BOOL)isSplashing
{
    return _splashView.isDrawing;
}
/** 是否可撤销 */
- (BOOL)splashCanUndo
{
    return _splashView.canUndo;
}
/** 撤销模糊 */
- (void)splashUndo
{
    [_splashView undo];
}

- (void)setSplashState:(BOOL)splashState
{
    if (splashState) {
        _splashView.state = LFSplashStateType_Paintbrush;
    } else {
        _splashView.state = LFSplashStateType_Mosaic;
    }
}

- (BOOL)splashState
{
    return _splashView.state == LFSplashStateType_Paintbrush;
}

/** 设置马赛克大小 */
- (void)setSplashWidth:(CGFloat)squareWidth
{
    _splashView.squareWidth = squareWidth;
}
/** 设置画笔大小 */
- (void)setPaintWidth:(CGFloat)paintWidth
{
    _splashView.paintSize = CGSizeMake(paintWidth, paintWidth);
}

@end

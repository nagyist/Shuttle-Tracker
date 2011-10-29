//
//  MapViewController.m
//  Shuttle-Tracker
//
//  Created by Brendon Justin on 1/29/11.
//  Copyright 2011 Brendon Justin. All rights reserved.
//

#import "MapViewController.h"
#import "JSONParser.h"
#import "MapPlacemark.h"
#import "IASKSettingsReader.h"

@interface UIImage (magentatocolor)

- (UIImage *)convertMagentatoColor:(UIColor *)newColor;

@end

//	From Stack Overflow (SO), with modifications:
@implementation UIImage (magentatocolor)

typedef enum {
    ALPHA = 0,
    BLUE = 1,
    GREEN = 2,
    RED = 3
} PIXELS;


//  Convert the magenta pixels in an image to a new color.
//  Returns a new image with retain count 1.
- (UIImage *)convertMagentatoColor:(UIColor *)newColor {
    CGSize size = [self size];
    int width = size.width;
    int height = size.height;
    
    // the pixels will be painted to this array
    //  Note that this will hold integer values [0,255]
    uint32_t *pixels = (uint32_t *) malloc(width * height * sizeof(uint32_t));
    
    // clear the pixels so any transparency is preserved
    memset(pixels, 0, width * height * sizeof(uint32_t));
    
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    
    // create a context with RGBA pixels
    CGContextRef context = CGBitmapContextCreate(pixels, width, height, 8, width * sizeof(uint32_t), colorSpace, 
                                                 kCGBitmapByteOrder32Little | kCGImageAlphaPremultipliedLast);
    
    //  Get an array of the rgb values of the new color.
    //  Note that these values are floating point values on [0,1] 
    const CGFloat *rgb = CGColorGetComponents(newColor.CGColor);
    
    // paint the bitmap to our context which will fill in the pixels array
    //  Again, the pixels array is storing integer values [0,255]
    CGContextDrawImage(context, CGRectMake(0, 0, width, height), [self CGImage]);
    
    for(int y = 0; y < height; y++) {
        for(int x = 0; x < width; x++) {
            uint8_t *rgbaPixel = (uint8_t *) &pixels[y * width + x];
            
            //  If the color of the current pixel is magenta, which is (255, 0, 255) in RGB,
            //  change the color to the new color.
            if (rgbaPixel[RED] == 255 && rgbaPixel[GREEN] == 0 && rgbaPixel[BLUE] == 255) {
                rgbaPixel[RED] = rgb[0] * 255.0f;
                rgbaPixel[GREEN] = rgb[1] * 255.0f;
                rgbaPixel[BLUE] = rgb[2] * 255.0f;
            }
        }
    }
    
    // create a new CGImageRef from our context with the modified pixels
    CGImageRef image = CGBitmapContextCreateImage(context);
    
    // we're done with the context, color space, and pixels
    CGContextRelease(context);
    CGColorSpaceRelease(colorSpace);
    free(pixels);
    
    // make a new UIImage to return
    UIImage *resultUIImage = [UIImage imageWithCGImage:image];
    [resultUIImage retain];
    
    // we're done with image now too
    CGImageRelease(image);
    
    return resultUIImage;
}

@end
//	End from SO


@interface MapViewController()
- (void)managedRoutesLoaded;
//	notifyVehiclesUpdated may not be called on the main thread, so use it to call
//	vehicles updated on the main thread.
- (void)notifyVehiclesUpdated:(NSNotification *)notification;
- (void)vehiclesUpdated:(NSNotification *)notification;
//	Adding routes and stops is not guaranteed to be done on the main thread.
- (void)addRoute:(MapRoute *)route;
- (void)addStop:(MapStop *)stop;
//	Adding vehicles should only be done on the main thread.
- (void)addJsonVehicle:(JSONVehicle *)vehicle;
- (void)settingChanged:(NSNotification *)notification;

@end


@implementation MapViewController

@synthesize dataManager;


// Implement loadView to create a view hierarchy programmatically, without using a nib.
- (void)loadView {
    CGRect rect = [[UIScreen mainScreen] bounds];
    
	_mapView = [[MKMapView alloc] initWithFrame:rect];
    _mapView.delegate = self;
	_mapView.autoresizingMask = UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleWidth;
    
	self.view = _mapView;
}

// Implement viewDidLoad to do additional setup after loading the view, typically from a nib.
- (void)viewDidLoad {
    [super viewDidLoad];
    
    routeLines = [[NSMutableArray alloc] init];
    routeLineViews = [[NSMutableArray alloc] init];
    
	//	Take notice when the routes and stops are updated.
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(managedRoutesLoaded) name:kDMRoutesandStopsLoaded object:nil];
	
	[dataManager loadRoutesAndStops];
    
    //  The RPI student union is at -73.6765441399,42.7302712352
    //  The center point used here is a bit south of it
    MKCoordinateRegion region;
    region.center.latitude = 42.7312;
    region.center.longitude = -73.6750;
    region.span.latitudeDelta = 0.0200;
    region.span.longitudeDelta = 0.0132;
    
    _mapView.region = region;
	
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	BOOL useLocation = [[defaults objectForKey:@"useLocation"] boolValue];
	
	if (useLocation) {
		//  Show the user's location on the map
		_mapView.showsUserLocation = YES;
	}
    
	shuttleImage = [UIImage imageNamed:@"shuttle"];
	[shuttleImage retain];
    
    magentaShuttleImage = [UIImage imageNamed:@"shuttle_color"];
    [magentaShuttleImage retain];
    
    shuttleImages = [[NSMutableDictionary alloc] init];
	
	//	Take notice when a setting is changed.
	//	Note that this is not the only object that takes notice.
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(settingChanged:) name:kIASKAppSettingChanged object:nil];
	
	//	Take notice when vehicles are updated.
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(notifyVehiclesUpdated:) name:kDMVehiclesUpdated object:nil];
}


//  The routes and stops were loaded in the dataManager
- (void)managedRoutesLoaded {
    for (MapRoute *route in [dataManager routes]) {
        [self addRoute:route];
    }
    
    for (MapStop *stop in [dataManager stops]) {
        [self addStop:stop];
    }
}

//	A notification is sent by DataManager whenever the vehicles are updated.
//	Call the work function vehiclesUpdated on the main thread.
- (void)notifyVehiclesUpdated:(NSNotification *)notification {
	[self performSelectorOnMainThread:@selector(vehiclesUpdated:) withObject:notification waitUntilDone:NO];
}

//	A notification is sent by DataManager whenever the vehicles are updated.
- (void)vehiclesUpdated:(NSNotification *)notification {
	NSDictionary *info = [notification userInfo];
	
	NSArray *dmVehicles = [info objectForKey:@"vehicles"];
	
	if (!dmVehicles) {
		return;
	}
	
	for (JSONVehicle *vehicle in dmVehicles) {
		if ([[_mapView annotations] indexOfObject:vehicle] == NSNotFound) {
			[self addJsonVehicle:vehicle];
		} else if (vehicle.viewNeedsUpdate) {
			//	If the annotation view needs to be updated, for example if the
			//	shuttle switched routes, then 1. Remove the shuttle from the map
			//	view, 2. Remove the associated annotation view, and 3. Add the
			//	shuttle back to the map view.
			[_mapView removeAnnotation:vehicle];
			vehicle.annotationView = nil;
			[self addJsonVehicle:vehicle];
		}
	}
	
	for (id existingObject in [_mapView annotations]) {
		if ([existingObject isKindOfClass:[JSONVehicle class]] && [dmVehicles indexOfObject:existingObject] == NSNotFound) {
			[_mapView removeAnnotation:existingObject];
		}
	}
}


//  Add the overlay for the route to the map view, and create a shuttle image with
//  a color matching the route's color
- (void)addRoute:(MapRoute *)route {
    NSArray *temp;
    CLLocationCoordinate2D clLoc;
    MKMapPoint *points = malloc(sizeof(MKMapPoint) * route.lineString.count);
    
    int counter = 0;
    
    //  Create an array of coordinates for the polyline which will represent the route
    for (NSString *coordinate in route.lineString) {
        temp = [coordinate componentsSeparatedByString:@","];
        
        if (temp && [temp count] > 1) {
            //  Get a CoreLocation coordinate from the coordinate string
            clLoc = CLLocationCoordinate2DMake([[temp objectAtIndex:1] floatValue], [[temp objectAtIndex:0] floatValue]);
            
            points[counter] = MKMapPointForCoordinate(clLoc);
            counter++;
        }
        
    }
    
    MKPolyline *polyLine = [MKPolyline polylineWithPoints:points count:counter];
    [routeLines addObject:polyLine];
    
    free(points);
    
    MKPolylineView *routeView = [[MKPolylineView alloc] initWithPolyline:polyLine];
    [routeLineViews addObject:routeView];
	[routeView release];
    
    routeView.lineWidth = route.style.width;
    routeView.fillColor = route.style.color;
    routeView.strokeColor = route.style.color;
    
    [_mapView addOverlay:polyLine];
    
    //  Create the colored shuttle image for the route
    UIImage *coloredImage;
    
    if (route.style.color) {
        coloredImage = [magentaShuttleImage convertMagentatoColor:route.style.color];
        
        [shuttleImages setValue:coloredImage forKey:route.idTag];
    }
}

- (void)addStop:(MapStop *)stop {
    [_mapView addAnnotation:stop];
    
}

- (void)addJsonVehicle:(JSONVehicle *)vehicle {
    [_mapView addAnnotation:vehicle];
}


//	InAppSettingsKit sends out a notification whenever a setting is changed in the settings view inside the app.
//	settingChanged currently only handles turning on or off showing the user's location.
//	Other objects may also do something when a setting is changed.
- (void)settingChanged:(NSNotification *)notification {
	NSDictionary *info = [notification userInfo];
	
	//	Set the date format to 24 hour time if the user has set Use 24 Hour Time to true.
	if ([[notification object] isEqualToString:@"useLocation"]) {
		if ([[info objectForKey:@"useLocation"] boolValue]) {
			_mapView.showsUserLocation = YES;
		} else {
			_mapView.showsUserLocation = NO;
		}
	}
}


// Override to allow orientations other than the default portrait orientation.
- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
    // Return YES for supported orientations.
    return YES;
}


- (void)didReceiveMemoryWarning {
    // Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
    
    // Release any cached data, images, etc. that aren't in use.
}

- (void)viewDidUnload {
    [super viewDidUnload];
    // Release any retained subviews of the main view.
    // e.g. self.myOutlet = nil;
}


- (void)dealloc {
    [_mapView release];
	[shuttleImage release];
    [super dealloc];
}


#pragma mark MKMapViewDelegate

- (MKOverlayView *)mapView:(MKMapView *)mapView viewForOverlay:(id<MKOverlay>)overlay {
    MKOverlayView* overlayView = nil;
    
    int counter = 0;
    
    for (MKPolyline *routeLine in routeLines) {
        if (routeLine == overlay) {
            overlayView = [routeLineViews objectAtIndex:counter];
            break;
        }
        
        counter++;
    }
    
    return overlayView;
}

- (MKAnnotationView *)mapView:(MKMapView *)mapView viewForAnnotation:(id<MKAnnotation>)annotation {
    //  If the annotation is the user's location, return nil so the platform
    //  just uses the blue dot
    if (annotation == _mapView.userLocation)
        return nil;
    
    if ([annotation isKindOfClass:[MapStop class]]) {
		if ([(MapStop *)annotation annotationView]) {
			return [(MapStop *)annotation annotationView];
		}
		
		MKAnnotationView *stopAnnotationView = [[[MKAnnotationView alloc] initWithAnnotation:(MapStop *)annotation reuseIdentifier:@"stopAnnotation"] autorelease];
        stopAnnotationView.image = [UIImage imageNamed:@"stop_marker"];
        stopAnnotationView.canShowCallout = YES;
        
        [(MapStop *)annotation setAnnotationView:stopAnnotationView];
		
		return stopAnnotationView;
    } else if ([annotation isKindOfClass:[JSONVehicle class]]) {
        JSONVehicle *vehicle = (JSONVehicle *)annotation;
        
        if ([vehicle annotationView]) {
            //  Check to see if the vehicle's image is the plain shuttle image.
            //  If it is, check for a colored shuttle image for the shuttle's route.
            //  Set the shuttle's image to the colored one, if we have it.
//            if (!vehicle.routeImageSet) {
//                if ([shuttleImages objectForKey:[NSNumber numberWithInt:[vehicle routeNo]]] != nil) {
//                    [[vehicle annotationView] setImage:[shuttleImages objectForKey:[NSNumber numberWithInt:[vehicle routeNo]]]];
//					vehicle.routeImageSet = YES;
//                }
//            }
            
            return [vehicle annotationView];
        }
        
        MKAnnotationView *vehicleAnnotationView = [[[MKAnnotationView alloc] initWithAnnotation:vehicle reuseIdentifier:@"vehicleAnnotation"] autorelease];
        
        //  Check if there is a colored shuttle image for the shuttle's current route.
        //  If there is, use it.
//        if ([shuttleImages objectForKey:[NSNumber numberWithInt:[vehicle routeNo]]] != nil) {
//            vehicleAnnotationView.image = [shuttleImages objectForKey:[NSNumber numberWithInt:[vehicle routeNo]]];
//			vehicle.routeImageSet = YES;
//        } else {
//            vehicleAnnotationView.image = shuttleImage;
//			vehicle.routeImageSet = NO;
//        }
        
        vehicleAnnotationView.image = shuttleImage;
        vehicle.routeImageSet = NO;
        
        vehicleAnnotationView.canShowCallout = YES;
        
        [vehicle setAnnotationView:vehicleAnnotationView];
		vehicle.viewNeedsUpdate = NO;
		
		return vehicleAnnotationView;
    }
    
    return nil;
}


@end
//
//  MapViewController.m
//  FavSpots
//
//  Created by Rob Napier on 8/11/12.
//  Copyright (c) 2012 Rob Napier. All rights reserved.
//

#import "MapViewController.h"
#import <MapKit/MapKit.h>
#import "MapViewAnnotation.h"
#import "Spot.h"
#import "DetailViewController.h"
#import "ModelController.h"
#import "NSCoder+RNMapKit.h"

static NSString * const kRegionKey = @"kRegionKey";
static NSString * const kUserTrackingKey = @"kUserTrackingKey";

@interface MapViewController () <MKMapViewDelegate, NSFetchedResultsControllerDelegate>
@property (weak, nonatomic) IBOutlet MKMapView *mapView;
@property (nonatomic, readwrite, strong) NSManagedObjectContext *managedObjectContext;
@property (nonatomic, readwrite, strong) NSFetchedResultsController *fetchedResultsController;
@end

@implementation MapViewController

- (void)encodeRestorableStateWithCoder:(NSCoder *)coder {
  [super encodeRestorableStateWithCoder:coder];
  
  [coder RN_encodeMKCoordinateRegion:self.mapView.region
                              forKey:kRegionKey];
  [coder encodeInteger:self.mapView.userTrackingMode
                forKey:kUserTrackingKey];
}

- (void)decodeRestorableStateWithCoder:(NSCoder *)coder {
  [super decodeRestorableStateWithCoder:coder];
  
  if ([coder containsValueForKey:kRegionKey]) {
    self.mapView.region =
    [coder RN_decodeMKCoordinateRegionForKey:kRegionKey];
  }
  
  self.mapView.userTrackingMode =
  [coder decodeIntegerForKey:kUserTrackingKey];
}

- (void)awakeFromNib {
  self.managedObjectContext = [[ModelController sharedController] managedObjectContext];
}

- (void)viewDidLoad
{
  [super viewDidLoad];
  UILongPressGestureRecognizer *lpgr = [[UILongPressGestureRecognizer alloc]
                                        initWithTarget:self action:@selector(handleLongPress:)];
  lpgr.minimumPressDuration = 1.5;
  [self.mapView addGestureRecognizer:lpgr];
  for (Spot *spot in [self.fetchedResultsController fetchedObjects]) {
    [self addAnnotationForSpot:spot];
  }
  
  MKUserTrackingBarButtonItem *buttonItem = [[MKUserTrackingBarButtonItem alloc] initWithMapView:self.mapView];
  self.navigationItem.rightBarButtonItem = buttonItem;
}

- (void)addAnnotationForSpot:(Spot *)spot
{
  MapViewAnnotation *ann = [[MapViewAnnotation alloc] initWithSpot:spot];
  [self.mapView addAnnotation:ann];
}

- (void)handleLongPress:(UIGestureRecognizer *)gestureRecognizer
{
  if (gestureRecognizer.state != UIGestureRecognizerStateBegan)
    return;
  
  CGPoint touchPoint = [gestureRecognizer locationInView:self.mapView];
  CLLocationCoordinate2D touchMapCoordinate =
  [self.mapView convertPoint:touchPoint toCoordinateFromView:self.mapView];
  
  Spot *spot = [Spot insertNewSpotWithCoordinate:touchMapCoordinate inManagedObjectContext:self.managedObjectContext];
  [self performSegueWithIdentifier:@"newSpot" sender:spot];
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
  if ([[segue identifier] isEqualToString:@"newSpot"]) {
    DetailViewController *detailVC = [segue destinationViewController];
    detailVC.spot = sender;
  }
}

- (NSFetchedResultsController *)fetchedResultsController
{
  if (_fetchedResultsController != nil) {
    return _fetchedResultsController;
  }
  
  NSManagedObjectContext *moc = [[ModelController sharedController] managedObjectContext];
  NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
  NSEntityDescription *entity = [NSEntityDescription entityForName:@"Spot" inManagedObjectContext:moc];
  [fetchRequest setEntity:entity];
  
  NSSortDescriptor *sortDescriptor = [[NSSortDescriptor alloc] initWithKey:@"name" ascending:NO];
  NSArray *sortDescriptors = @[sortDescriptor];
  
  [fetchRequest setSortDescriptors:sortDescriptors];
  NSFetchedResultsController *aFetchedResultsController = [[NSFetchedResultsController alloc] initWithFetchRequest:fetchRequest
                                                                                              managedObjectContext:moc
                                                                                                sectionNameKeyPath:nil
                                                                                                         cacheName:@"MapView"];
  aFetchedResultsController.delegate = self;
  self.fetchedResultsController = aFetchedResultsController;
  
	NSError *error = nil;
	if (![self.fetchedResultsController performFetch:&error]) {
    // Replace this implementation with code to handle the error appropriately.
    // abort() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
    NSLog(@"Unresolved error %@, %@", error, [error userInfo]);
    abort();
	}
  
  return _fetchedResultsController;
}

- (void)removeObjectForSpot:(Spot *)spot
{
  for (MapViewAnnotation *ann in self.mapView.annotations) {
    if ([ann.spot isEqual:spot]) {
      [self.mapView removeAnnotation:ann];
      break;
    }
  }
}

- (void)controller:(NSFetchedResultsController *)controller didChangeObject:(id)anObject
       atIndexPath:(NSIndexPath *)indexPath forChangeType:(NSFetchedResultsChangeType)type
      newIndexPath:(NSIndexPath *)newIndexPath
{
  switch(type) {
    case NSFetchedResultsChangeInsert:
      [self addAnnotationForSpot:anObject];
      break;
      
    case NSFetchedResultsChangeDelete:
      [self removeObjectForSpot:anObject];
      break;
      
    case NSFetchedResultsChangeUpdate:
      break;
      
    case NSFetchedResultsChangeMove:
      break;
  }
}

- (void)mapView:(MKMapView *)mapView didSelectAnnotationView:(MKAnnotationView *)view
{
  if ([view.annotation isKindOfClass:[MapViewAnnotation class]]) {
    MapViewAnnotation *ann = view.annotation;
    [self performSegueWithIdentifier:@"newSpot" sender:ann.spot];
    [self.mapView deselectAnnotation:view.annotation animated:NO];
  }
}

@end

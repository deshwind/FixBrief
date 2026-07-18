import 'package:flutter/material.dart';

@immutable
class RepairCategory {
  const RepairCategory({
    required this.slug,
    required this.label,
    required this.icon,
    required this.subcategories,
    required this.suggestedSymptoms,
  });

  final String slug;
  final String label;
  final IconData icon;
  final List<String> subcategories;
  final List<String> suggestedSymptoms;
}

abstract final class RepairCategoryCatalogue {
  static const categories = <RepairCategory>[
    RepairCategory(
      slug: 'vehicles',
      label: 'Vehicles',
      icon: Icons.directions_car_filled_rounded,
      subcategories: ['Car', 'Van', 'Motorcycle', 'Camper', 'Other vehicle'],
      suggestedSymptoms: [
        'Won’t start',
        'Warning light',
        'Unusual noise',
        'Loss of power',
        'Fluid leak',
        'Vibration',
      ],
    ),
    RepairCategory(
      slug: 'plumbing',
      label: 'Plumbing',
      icon: Icons.plumbing_rounded,
      subcategories: ['Leak', 'Tap', 'Toilet', 'Shower', 'Pipework', 'Drain'],
      suggestedSymptoms: [
        'Leaking',
        'Low pressure',
        'Blocked',
        'No hot water',
        'Bad smell',
      ],
    ),
    RepairCategory(
      slug: 'electrical',
      label: 'Electrical',
      icon: Icons.electrical_services_rounded,
      subcategories: ['Socket', 'Lighting', 'Fuse board', 'Wiring', 'Other'],
      suggestedSymptoms: [
        'No power',
        'Tripping',
        'Flickering',
        'Buzzing',
        'Burning smell',
      ],
    ),
    RepairCategory(
      slug: 'appliances',
      label: 'Appliances',
      icon: Icons.kitchen_rounded,
      subcategories: [
        'Washing machine',
        'Dishwasher',
        'Fridge/freezer',
        'Oven',
        'Dryer',
        'Other appliance',
      ],
      suggestedSymptoms: [
        'Won’t turn on',
        'Not heating',
        'Leaking',
        'Error code',
        'Unusual noise',
        'Vibration',
      ],
    ),
    RepairCategory(
      slug: 'computers',
      label: 'Computers & phones',
      icon: Icons.laptop_mac_rounded,
      subcategories: ['Laptop', 'Desktop', 'Phone', 'Tablet', 'Printer'],
      suggestedSymptoms: [
        'Won’t power on',
        'Overheating',
        'Slow or freezing',
        'Damaged screen',
        'Not charging',
      ],
    ),
    RepairCategory(
      slug: 'bicycles',
      label: 'Bicycles',
      icon: Icons.pedal_bike_rounded,
      subcategories: ['Road', 'Mountain', 'Electric', 'Hybrid', 'Children’s'],
      suggestedSymptoms: [
        'Brakes rubbing',
        'Gears slipping',
        'Puncture',
        'Wheel wobble',
        'Motor fault',
      ],
    ),
    RepairCategory(
      slug: 'property',
      label: 'Property',
      icon: Icons.home_repair_service_rounded,
      subcategories: ['Door/window', 'Roof', 'Wall/floor', 'Heating', 'Other'],
      suggestedSymptoms: [
        'Water damage',
        'Crack or movement',
        'Draught',
        'Sticking',
        'Not heating',
      ],
    ),
    RepairCategory(
      slug: 'industrial',
      label: 'Industrial equipment',
      icon: Icons.precision_manufacturing_rounded,
      subcategories: ['Motor', 'Pump', 'Compressor', 'Control system', 'Other'],
      suggestedSymptoms: [
        'Unexpected shutdown',
        'Overheating',
        'Vibration',
        'Pressure loss',
        'Error code',
      ],
    ),
    RepairCategory(
      slug: 'other',
      label: 'Other',
      icon: Icons.category_rounded,
      subcategories: ['Other'],
      suggestedSymptoms: [
        'Won’t work',
        'Unusual noise',
        'Intermittent fault',
        'Physical damage',
      ],
    ),
  ];

  static RepairCategory? bySlug(String? slug) {
    for (final category in categories) {
      if (category.slug == slug) {
        return category;
      }
    }
    return null;
  }
}

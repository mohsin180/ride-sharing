import 'package:flutter/material.dart';
import 'package:ride_sharing/view/homepage.dart';
import 'package:ride_sharing/view/passengerScreens/profile.dart';
import 'package:ride_sharing/view/rideScreen.dart';
import 'package:ride_sharing/view/yourRide.dart';
import 'package:ride_sharing/widgets/consonants/consonants.dart';

class Bottomnavbar extends StatefulWidget {
  const Bottomnavbar({super.key});

  @override
  State<Bottomnavbar> createState() => _BottomnavbarState();
}

class _BottomnavbarState extends State<Bottomnavbar> {
  int currentIndex = 0;
  final List<Widget> screens = [
    Homepage(),
    Ridescreen(),
    Yourride(),
    Profile(),
  ];
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Consonants.scaffoldBackgroundColor,
      body: IndexedStack(index: currentIndex, children: screens),
      bottomNavigationBar: NavigationBarTheme(
        data: NavigationBarThemeData(
          indicatorColor: Colors.transparent,
          labelTextStyle: WidgetStatePropertyAll(
            const TextStyle(
              fontSize: 12.0,
              fontWeight: FontWeight.w500,
              color: Consonants.boldTextColor,
            ),
          ),
        ),
        child: NavigationBar(
          height: 70,
          selectedIndex: currentIndex,
          animationDuration: const Duration(milliseconds: 300),
          backgroundColor: Consonants.whiteColor,
          onDestinationSelected: (index) {
            setState(() {
              currentIndex = index;
            });
          },
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.home_outlined, color: Consonants.greyColor),
              selectedIcon: Icon(Icons.home, color: Consonants.primaryColor),
              label: "Home",
            ),
            NavigationDestination(
              icon: Icon(
                Icons.directions_car_outlined,
                color: Consonants.greyColor,
              ),
              selectedIcon: Icon(
                Icons.directions_car,
                color: Consonants.primaryColor,
              ),
              label: "Ride",
            ),
            NavigationDestination(
              icon: Icon(Icons.route_outlined, color: Consonants.greyColor),
              selectedIcon: Icon(Icons.route, color: Consonants.primaryColor),
              label: "Your Ride",
            ),
            NavigationDestination(
              icon: Icon(Icons.person_outline, color: Consonants.greyColor),
              selectedIcon: Icon(Icons.person, color: Consonants.primaryColor),
              label: "Profile",
            ),
          ],
        ),
      ),
    );
  }
}

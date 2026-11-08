import 'package:flutter/material.dart';

void main() {
  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
                        debugShowCheckedModeBanner:false,
                        home: ProfilePage(),
    );
  }
}


class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
                return Scaffold(
                  backgroundColor: const Color.fromARGB(255, 212, 212, 212),
                                appBar: AppBar(

                                                title: Text("My Profile", style: TextStyle(color:Colors.white, fontWeight: FontWeight.bold)),
                                                backgroundColor: Colors.teal
                                ),

                                body: Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,

                                    children: [

                                      const CircleAvatar(
                                        radius: 45,
                                        child: Icon(Icons.person, size:45)
                                      ),

                                      const SizedBox(height: 15),

                                      Text("Muhammad Muneeb", style:TextStyle(fontWeight:FontWeight.bold, color: Colors.black, fontSize: 25)),

                                      const SizedBox(height: 15),

                                      Text("BS Computer Science", style:TextStyle(color:const Color.fromARGB(255, 116, 116, 116))),

                                      const SizedBox(height: 15),

                                      Card( 
                                        child: Padding(
                                          padding: EdgeInsets.all(20),
                                          child: Column(
                                            children: [
                                                    Text("University: Riphah International Sahiwal",style:TextStyle(fontWeight:FontWeight.bold)),
                                                    Text("Semester: 5th")
                                            ],
                                          )
                                        )
                                      ),

                                      const SizedBox(height: 15),

                                      ElevatedButton(
                                        onPressed: (){
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            const SnackBar(
                                            content: Text("Project Opened", style:TextStyle(color:Colors.white)),
                                            backgroundColor: Colors.green
                                          )
                                          );
                                        },

                                        style: ButtonStyle(
                                          backgroundColor: const WidgetStatePropertyAll(Colors.green),
                                          foregroundColor: const WidgetStatePropertyAll(Colors.white)
                                          ),

                                        child: Text("Proceed To Project", style:TextStyle(fontWeight:FontWeight.bold))
                                      )


                                    ],
                                  )
                                ),
                                
                        );
  }
}
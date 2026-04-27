import 'package:flutter/material.dart';
import 'services/auth_service.dart';

class LoginPage extends StatefulWidget {
  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final AuthService _auth = AuthService();

  String message = "";

  void login() async {
    var user = await _auth.login(
      emailController.text,
      passwordController.text,
    );

    setState(() {
      message = user != null ? "Login Success" : "Login Failed";
    });
  }

  void signup() async {
    var user = await _auth.signUp(
      emailController.text,
      passwordController.text,
    );

    setState(() {
      message = user != null ? "Signup Success" : "Signup Failed";
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Firebase Auth")),
      body: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: emailController,
              decoration: InputDecoration(labelText: "Email"),
            ),
            TextField(
              controller: passwordController,
              decoration: InputDecoration(labelText: "Password"),
              obscureText: true,
            ),
            SizedBox(height: 20),
            ElevatedButton(onPressed: login, child: Text("Login")),
            ElevatedButton(onPressed: signup, child: Text("Sign Up")),
            SizedBox(height: 20),
            Text(message),
          ],
        ),
      ),
    );
  }
}
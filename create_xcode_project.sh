#!/bin/bash

cd /Users/abdelwahab/veralify/veralify-ios

# Create Swift Package structure that Xcode can convert
mkdir -p Veralify/Sources/Veralify
mkdir -p Veralify/Tests

# Create main files
cat > Veralify/Sources/Veralify/VeralifyApp.swift << 'SWIFT'
import SwiftUI

@main
struct VeralifyApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
SWIFT

cat > Veralify/Sources/Veralify/ContentView.swift << 'SWIFT'
import SwiftUI

struct ContentView: View {
    @StateObject private var authManager = AuthManager()
    
    var body: some View {
        if authManager.isLoggedIn {
            MainTabView(authManager: authManager)
        } else {
            LoginView(authManager: authManager)
        }
    }
}

class AuthManager: ObservableObject {
    @Published var isLoggedIn = false
    @Published var userEmail = ""
    @Published var userRole = "worker"
    
    func loginWithGoogle() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.userEmail = "user@gmail.com"
            self.userRole = "admin"
            self.isLoggedIn = true
        }
    }
    
    func loginWithApple() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.userEmail = "user@icloud.com"
            self.userRole = "worker"
            self.isLoggedIn = true
        }
    }
    
    func logout() {
        isLoggedIn = false
        userEmail = ""
    }
}

struct LoginView: View {
    @ObservedObject var authManager: AuthManager
    
    var body: some View {
        ZStack {
            Color(.systemBackground).ignoresSafeArea()
            
            VStack(spacing: 30) {
                VStack(spacing: 12) {
                    Image(systemName: "lock.circle.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.blue)
                    
                    Text("Veralify")
                        .font(.title)
                        .fontWeight(.bold)
                    
                    Text("Organization Document Management")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 60)
                
                Spacer()
                
                VStack(spacing: 12) {
                    Button(action: authManager.loginWithGoogle) {
                        HStack {
                            Image(systemName: "g.circle.fill")
                            Text("Sign in with Google")
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                    }
                    
                    Button(action: authManager.loginWithApple) {
                        HStack {
                            Image(systemName: "applelogo")
                            Text("Sign in with Apple")
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.black)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                    }
                }
                .padding(.bottom, 40)
            }
            .padding()
        }
    }
}

struct MainTabView: View {
    @ObservedObject var authManager: AuthManager
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            DashboardView(authManager: authManager)
                .tabItem {
                    Label("Dashboard", systemImage: "chart.bar.fill")
                }
                .tag(0)
            
            ProfileView(authManager: authManager)
                .tabItem {
                    Label("Profile", systemImage: "person.fill")
                }
                .tag(1)
        }
    }
}

struct DashboardView: View {
    @ObservedObject var authManager: AuthManager
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                ScrollView {
                    VStack(spacing: 15) {
                        HStack(spacing: 15) {
                            StatCard(title: "Documents", value: "0", icon: "doc.fill", color: .blue)
                            StatCard(title: "Projects", value: "5", icon: "folder.fill", color: .orange)
                        }
                        
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Recent Documents")
                                .font(.headline)
                                .padding(.horizontal)
                            
                            if authManager.userRole == "admin" {
                                DocumentRow(title: "Upload Document", icon: "plus.circle.fill", color: .blue)
                                    .padding(.horizontal)
                            } else {
                                Text("No documents assigned yet")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                                    .padding()
                            }
                        }
                        
                        Spacer()
                    }
                    .padding()
                }
            }
            .navigationTitle("Dashboard")
        }
    }
}

struct ProfileView: View {
    @ObservedObject var authManager: AuthManager
    @State private var showingSignOut = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                VStack(spacing: 15) {
                    Image(systemName: "person.circle.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.blue)
                    
                    Text("Profile")
                        .font(.headline)
                }
                .padding(.top, 30)
                
                VStack(alignment: .leading, spacing: 15) {
                    ProfileField(label: "Email", value: authManager.userEmail)
                    ProfileField(label: "Role", value: authManager.userRole.uppercased())
                    ProfileField(label: "Organization", value: "Veralify")
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
                
                Spacer()
                
                Button(action: { showingSignOut = true }) {
                    Text("Sign Out")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.red)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
                .padding()
            }
            .navigationTitle("Profile")
            .alert("Sign Out", isPresented: $showingSignOut) {
                Button("Sign Out", role: .destructive) {
                    authManager.logout()
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("Are you sure you want to sign out?")
            }
        }
    }
}

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 5) {
                    Text(title).font(.subheadline).foregroundColor(.gray)
                    Text(value).font(.title2).fontWeight(.bold)
                }
                Spacer()
                Image(systemName: icon).font(.system(size: 24)).foregroundColor(color)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .border(color, width: 1)
        .cornerRadius(12)
    }
}

struct DocumentRow: View {
    let title: String
    let icon: String
    let color: Color
    
    var body: some View {
        HStack {
            Image(systemName: icon).foregroundColor(color)
            Text(title).fontWeight(.semibold)
            Spacer()
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
}

struct ProfileField: View {
    let label: String
    let value: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(label).font(.caption).fontWeight(.semibold).foregroundColor(.gray)
            Text(value).font(.body).fontWeight(.medium)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.systemBackground))
        .cornerRadius(8)
    }
}

#Preview {
    ContentView()
}
SWIFT

echo "✅ Veralify iOS app created successfully!"
echo ""
echo "To open in Xcode:"
echo "  open /Users/abdelwahab/veralify/veralify-ios/Veralify"

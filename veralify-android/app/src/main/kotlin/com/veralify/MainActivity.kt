package com.veralify

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.BarChart
import androidx.compose.material.icons.filled.DocumentScanner
import androidx.compose.material.icons.filled.Person
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.Card
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.NavigationBar
import androidx.compose.material3.NavigationBarItem
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.veralify.ui.theme.VeralifyTheme

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContent {
            VeralifyTheme {
                VeralifyApp()
            }
        }
    }
}

private enum class UserRole {
    ADMIN,
    WORKER
}

private data class UserSession(
    val email: String,
    val role: UserRole,
    val organization: String
)

private class AuthManager {
    val session = mutableStateOf<UserSession?>(null)
    val isLoggedIn = mutableStateOf(false)

    fun signInWithGoogle() {
        session.value = UserSession(
            email = "admin@veralify.com",
            role = UserRole.ADMIN,
            organization = "Veralify"
        )
        isLoggedIn.value = true
    }

    fun signInWithApple() {
        session.value = UserSession(
            email = "worker@veralify.com",
            role = UserRole.WORKER,
            organization = "Veralify"
        )
        isLoggedIn.value = true
    }

    fun signOut() {
        session.value = null
        isLoggedIn.value = false
    }
}

@Composable
private fun VeralifyApp() {
    val authManager = remember { AuthManager() }

    if (authManager.isLoggedIn.value) {
        MainScreen(authManager)
    } else {
        LoginScreen(authManager)
    }
}

@Composable
private fun LoginScreen(authManager: AuthManager) {
    Column(
        modifier = Modifier
            .fillMaxSize()
            .padding(20.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.SpaceBetween
    ) {
        Spacer(modifier = Modifier.height(56.dp))

        Column(horizontalAlignment = Alignment.CenterHorizontally) {
            Icon(
                imageVector = Icons.Default.DocumentScanner,
                contentDescription = null,
                modifier = Modifier.height(80.dp),
                tint = MaterialTheme.colorScheme.primary
            )

            Spacer(modifier = Modifier.height(12.dp))

            Text("Veralify", fontSize = 30.sp, fontWeight = FontWeight.Bold)
            Text(
                "Organization document management",
                color = MaterialTheme.colorScheme.onSurfaceVariant
            )
        }

        Column(
            modifier = Modifier.fillMaxWidth(),
            verticalArrangement = Arrangement.spacedBy(12.dp)
        ) {
            Button(
                onClick = authManager::signInWithGoogle,
                modifier = Modifier
                    .fillMaxWidth()
                    .height(48.dp)
            ) {
                Text("Sign in with Google")
            }

            Button(
                onClick = authManager::signInWithApple,
                modifier = Modifier
                    .fillMaxWidth()
                    .height(48.dp),
                colors = ButtonDefaults.buttonColors(containerColor = MaterialTheme.colorScheme.secondary)
            ) {
                Text("Sign in with Apple")
            }
        }

        Spacer(modifier = Modifier.height(32.dp))
    }
}

@Composable
private fun MainScreen(authManager: AuthManager) {
    var selectedTab by remember { mutableIntStateOf(0) }

    Scaffold(
        bottomBar = {
            NavigationBar {
                NavigationBarItem(
                    selected = selectedTab == 0,
                    onClick = { selectedTab = 0 },
                    icon = { Icon(Icons.Default.BarChart, contentDescription = null) },
                    label = { Text("Dashboard") }
                )
                NavigationBarItem(
                    selected = selectedTab == 1,
                    onClick = { selectedTab = 1 },
                    icon = { Icon(Icons.Default.Person, contentDescription = null) },
                    label = { Text("Profile") }
                )
            }
        }
    ) { padding ->
        when (selectedTab) {
            0 -> DashboardScreen(authManager, padding)
            else -> ProfileScreen(authManager, padding)
        }
    }
}

@Composable
private fun DashboardScreen(authManager: AuthManager, padding: PaddingValues) {
    Column(
        modifier = Modifier
            .fillMaxSize()
            .padding(padding)
            .padding(16.dp)
    ) {
        Text("Dashboard", fontSize = 28.sp, fontWeight = FontWeight.Bold)

        authManager.session.value?.email?.let { email ->
            Text(
                "Welcome, $email",
                color = MaterialTheme.colorScheme.onSurfaceVariant
            )
        }

        Spacer(modifier = Modifier.height(16.dp))

        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.spacedBy(12.dp)
        ) {
            StatCard("Documents", "0", Modifier.weight(1f))
            StatCard("Projects", "5", Modifier.weight(1f))
        }

        Spacer(modifier = Modifier.height(16.dp))
        Text("Recent Documents", fontSize = 18.sp, fontWeight = FontWeight.Bold)
        Spacer(modifier = Modifier.height(8.dp))

        Card(modifier = Modifier.fillMaxWidth()) {
            Row(modifier = Modifier.padding(16.dp), verticalAlignment = Alignment.CenterVertically) {
                if (authManager.session.value?.role == UserRole.ADMIN) {
                    Icon(Icons.Default.Add, contentDescription = null)
                    Text(" Upload document")
                } else {
                    Text("No documents assigned yet")
                }
            }
        }
    }
}

@Composable
private fun ProfileScreen(authManager: AuthManager, padding: PaddingValues) {
    var showSignOutDialog by remember { mutableStateOf(false) }
    val session = authManager.session.value

    Column(
        modifier = Modifier
            .fillMaxSize()
            .padding(padding)
            .padding(16.dp)
    ) {
        Text("Profile", fontSize = 28.sp, fontWeight = FontWeight.Bold)
        Spacer(modifier = Modifier.height(16.dp))

        Card(modifier = Modifier.fillMaxWidth()) {
            Column(
                modifier = Modifier.padding(16.dp),
                verticalArrangement = Arrangement.spacedBy(12.dp)
            ) {
                ProfileField("Email", session?.email ?: "-")
                ProfileField("Role", session?.role?.name ?: "-")
                ProfileField("Organization", session?.organization ?: "-")
            }
        }

        Spacer(modifier = Modifier.weight(1f))

        Button(
            onClick = { showSignOutDialog = true },
            modifier = Modifier
                .fillMaxWidth()
                .height(48.dp),
            colors = ButtonDefaults.buttonColors(containerColor = MaterialTheme.colorScheme.error)
        ) {
            Text("Sign out")
        }
    }

    if (showSignOutDialog) {
        AlertDialog(
            onDismissRequest = { showSignOutDialog = false },
            title = { Text("Sign out?") },
            text = { Text("You will need to authenticate again.") },
            confirmButton = {
                Button(onClick = {
                    authManager.signOut()
                    showSignOutDialog = false
                }) {
                    Text("Sign out")
                }
            },
            dismissButton = {
                Button(onClick = { showSignOutDialog = false }) {
                    Text("Cancel")
                }
            }
        )
    }
}

@Composable
private fun StatCard(title: String, value: String, modifier: Modifier = Modifier) {
    Card(modifier = modifier) {
        Column(
            modifier = Modifier.padding(14.dp),
            verticalArrangement = Arrangement.spacedBy(8.dp)
        ) {
            Text(title, color = MaterialTheme.colorScheme.onSurfaceVariant)
            Text(value, fontSize = 24.sp, fontWeight = FontWeight.Bold)
        }
    }
}

@Composable
private fun ProfileField(label: String, value: String) {
    Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
        Text(
            text = label,
            fontSize = 12.sp,
            fontWeight = FontWeight.SemiBold,
            color = MaterialTheme.colorScheme.onSurfaceVariant
        )
        Text(text = value, fontSize = 16.sp, fontWeight = FontWeight.Medium)
    }
}

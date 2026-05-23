package com.gmos.ui

import android.content.ClipData
import android.content.ClipDescription
import android.content.ComponentName
import android.content.Intent
import android.content.pm.ResolveInfo
import android.graphics.Color
import android.os.Bundle
import android.view.DragEvent
import android.view.LayoutInflater
import android.view.View
import android.view.ViewGroup
import android.widget.FrameLayout
import android.widget.ImageView
import android.widget.TextView
import android.widget.Toast
import androidx.appcompat.app.AppCompatActivity
import androidx.recyclerview.widget.GridLayoutManager
import androidx.recyclerview.widget.LinearLayoutManager
import androidx.recyclerview.widget.RecyclerView
import java.lang.Exception

/**
 * MainActivity do GM UI Launcher.
 * Gerencia a Barra de Tarefas (Taskbar), Gaveta de Apps (App Drawer) e a
 * Área de Trabalho (Workspace) com suporte para Drag-and-Drop de atalhos.
 */
class MainActivity : AppCompatActivity() {

    private lateinit var rootLayout: View
    private lateinit var workspace: FrameLayout
    private lateinit var desktopShortcutsContainer: FrameLayout
    private lateinit var appDrawerContainer: FrameLayout
    private lateinit var rvApps: RecyclerView
    private lateinit var rvPinnedApps: RecyclerView
    
    private var isDrawerOpen = false

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_main)

        rootLayout = findViewById(R.id.root_layout)
        workspace = findViewById(R.id.workspace)
        desktopShortcutsContainer = findViewById(R.id.desktop_shortcuts_container)
        appDrawerContainer = findViewById(R.id.app_drawer_container)
        rvApps = findViewById(R.id.rv_apps)
        rvPinnedApps = findViewById(R.id.rv_pinned_apps)

        // Configuração do botão da gaveta de aplicativos (App Drawer)
        findViewById<View>(R.id.btn_app_drawer).setOnClickListener {
            toggleAppDrawer()
        }

        // Configuração do botão de configurações rápidas
        findViewById<View>(R.id.btn_settings).setOnClickListener {
            try {
                val intent = Intent(android.provider.Settings.ACTION_SETTINGS)
                startActivity(intent)
            } catch (e: Exception) {
                Toast.makeText(this, "Não foi possível abrir as Configurações", Toast.LENGTH_SHORT).show()
            }
        }

        // Carrega a lista de aplicativos instalados na gaveta
        setupAppDrawer()

        // Configura a barra de favoritos vertical (RecyclerView simples para apps fixados)
        setupPinnedAppsBar()

        // Define o DragListener para a área de trabalho (Workspace) aceitar o drop dos apps
        desktopShortcutsContainer.setOnDragListener(WorkspaceDragListener())
    }

    /**
     * Abre ou fecha a Gaveta de Apps com um painel deslizante.
     */
    private fun toggleAppDrawer() {
        isDrawerOpen = !isDrawerOpen
        appDrawerContainer.visibility = if (isDrawerOpen) View.VISIBLE else View.GONE
    }

    /**
     * Lista todos os aplicativos com filtros de Launchers e carrega-os no RecyclerView.
     */
    private fun setupAppDrawer() {
        val pm = packageManager
        val mainIntent = Intent(Intent.ACTION_MAIN, null).apply {
            addCategory(Intent.CATEGORY_LAUNCHER)
        }
        
        // Obtém todas as Activities que podem ser iniciadas pelo usuário
        val appsList = pm.queryIntentActivities(mainIntent, 0)

        // Configura Grid Layout de 3 colunas para a gaveta de apps
        rvApps.layoutManager = GridLayoutManager(this, 3)
        rvApps.adapter = AppAdapter(appsList, isFromDrawer = true) { appInfo ->
            // Clique comum: inicia o aplicativo
            val intent = pm.getLaunchIntentForPackage(appInfo.activityInfo.packageName)
            if (intent != null) {
                startActivity(intent)
                toggleAppDrawer() // Fecha a gaveta após abrir o app
            }
        }
    }

    /**
     * Configura uma barra de favoritos vertical com alguns aplicativos pré-definidos (Ex: Browser, Configurações).
     */
    private fun setupPinnedAppsBar() {
        val pm = packageManager
        val mainIntent = Intent(Intent.ACTION_MAIN, null).apply {
            addCategory(Intent.CATEGORY_LAUNCHER)
        }
        val allApps = pm.queryIntentActivities(mainIntent, 0)
        
        // Filtra alguns aplicativos comuns para fixar na barra esquerda por padrão
        val pinnedPackages = listOf("com.android.chrome", "com.google.android.youtube", "com.android.settings")
        val pinnedList = allApps.filter { pinnedPackages.contains(it.activityInfo.packageName) }

        rvPinnedApps.layoutManager = LinearLayoutManager(this, RecyclerView.VERTICAL, false)
        rvPinnedApps.adapter = AppAdapter(pinnedList, isFromDrawer = false) { appInfo ->
            val intent = pm.getLaunchIntentForPackage(appInfo.activityInfo.packageName)
            if (intent != null) startActivity(intent)
        }
    }

    /**
     * RecyclerView Adapter genérico para carregar os ícones de aplicativos.
     */
    private inner class AppAdapter(
        private val apps: List<ResolveInfo>,
        private val isFromDrawer: Boolean,
        private val onItemClick: (ResolveInfo) -> Unit
    ) : RecyclerView.Adapter<AppViewHolder>() {

        override fun onCreateViewHolder(parent: ViewGroup, viewType: Int): AppViewHolder {
            val view = LayoutInflater.from(parent.context).inflate(R.layout.item_app, parent, false)
            return AppViewHolder(view)
        }

        override fun onBindViewHolder(holder: AppViewHolder, position: Int) {
            holder.bind(apps[position])
        }

        override fun getItemCount(): Int = apps.size
    }

    /**
     * ViewHolder contendo o ícone, nome e ações do aplicativo.
     */
    private inner class AppViewHolder(itemView: View) : RecyclerView.ViewHolder(itemView) {
        private val imgIcon: ImageView = itemView.findViewById(R.id.img_app_icon)
        private val txtName: TextView = itemView.findViewById(R.id.txt_app_name)

        fun bind(appInfo: ResolveInfo) {
            val pm = packageManager
            txtName.text = appInfo.loadLabel(pm)
            imgIcon.setImageDrawable(appInfo.loadIcon(pm))

            itemView.setOnClickListener {
                onItemClick(appInfo)
            }

            // DRAG AND DROP: O LongClick inicia a exportação de dados para o Workspace
            if (isFromDrawer) {
                itemView.setOnLongClickListener { view ->
                    val packageName = appInfo.activityInfo.packageName
                    val className = appInfo.activityInfo.name
                    val appLabel = appInfo.loadLabel(pm).toString()

                    // Serializa os dados do app para transferência segura durante o arrasto
                    val dragData = ClipData.newPlainText(
                        "APP_LAUNCHER_DATA",
                        "$packageName|$className|$appLabel"
                    )

                    // Cria a sombra visual (Drag Shadow) que acompanha o ponteiro/dedo
                    val shadowBuilder = View.DragShadowBuilder(view)

                    // Inicia o processo de Drag-and-Drop do Android SDK
                    view.startDragAndDrop(dragData, shadowBuilder, null, 0)

                    // Fecha a gaveta para que a Área de Trabalho fique visível durante o drop
                    toggleAppDrawer()
                    true
                }
            }
        }
    }

    /**
     * Implementação de View.OnDragListener na Área de Trabalho (Workspace).
     * Intercepta eventos de arrasto e cria atalhos persistentes.
     */
    private inner class WorkspaceDragListener : View.OnDragListener {
        override fun onDrag(v: View, event: DragEvent): Boolean {
            return when (event.action) {
                DragEvent.ACTION_DRAG_STARTED -> {
                    // Garante que só aceitamos arrastos contendo dados de texto plano (nosso payload)
                    event.clipDescription.hasMimeType(ClipDescription.MIMETYPE_TEXT_PLAIN)
                }

                DragEvent.ACTION_DRAG_ENTERED -> {
                    // Efeito visual ao passar por cima da Área de Trabalho (ex: borda translúcida)
                    workspace.setBackgroundColor(Color.parseColor("#1AFFFFFF"))
                    true
                }

                DragEvent.ACTION_DRAG_EXITED -> {
                    // Remove feedback visual
                    workspace.setBackgroundColor(Color.TRANSPARENT)
                    true
                }

                DragEvent.ACTION_DROP -> {
                    // Usuário soltou o ícone: processa os metadados
                    val item = event.clipData.getItemAt(0)
                    val dragData = item.text.toString() // Formato: "pacote|classe|nome"
                    
                    val parts = dragData.split("|")
                    if (parts.size >= 3) {
                        val packageName = parts[0]
                        val className = parts[1]
                        val appLabel = parts[2]

                        // Obtém as coordenadas exatas onde o cursor soltou o objeto
                        val dropX = event.x
                        val dropY = event.y

                        // Cria o atalho visual e funcional no Workspace
                        createDesktopShortcut(packageName, className, appLabel, dropX, dropY)
                    }
                    true
                }

                DragEvent.ACTION_DRAG_ENDED -> {
                    // Restaura o estado normal do fundo
                    workspace.setBackgroundColor(Color.TRANSPARENT)
                    true
                }

                else -> false
            }
        }
    }

    /**
     * Instancia o layout do atalho e o adiciona dinamicamente na Área de Trabalho com base
     * em coordenadas absolutas de tela calculadas a partir do drop.
     */
    private fun createDesktopShortcut(
        packageName: String,
        className: String,
        label: String,
        x: Float,
        y: Float
    ) {
        val pm = packageManager
        // Infla o mesmo layout de ícone do aplicativo
        val shortcutView = LayoutInflater.from(this).inflate(R.layout.item_app, desktopShortcutsContainer, false)

        val imgIcon: ImageView = shortcutView.findViewById(R.id.img_app_icon)
        val txtName: TextView = shortcutView.findViewById(R.id.txt_app_name)

        txtName.text = label
        txtName.setTextColor(Color.WHITE)
        
        try {
            val icon = pm.getActivityIcon(ComponentName(packageName, className))
            imgIcon.setImageDrawable(icon)
        } catch (e: Exception) {
            imgIcon.setImageResource(android.R.drawable.sym_def_app_icon)
        }

        // Configura ação de clique do atalho criado na Área de Trabalho
        shortcutView.setOnClickListener {
            val intent = Intent(Intent.ACTION_MAIN).apply {
                addCategory(Intent.CATEGORY_LAUNCHER)
                component = ComponentName(packageName, className)
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_RESET_TASK_IF_NEEDED
            }
            try {
                startActivity(intent)
            } catch (e: Exception) {
                Toast.makeText(this, "Não foi possível abrir o app", Toast.LENGTH_SHORT).show()
            }
        }

        // Obtém o tamanho padrão dos atalhos definido no dimens.xml
        val shortcutSize = resources.getDimensionPixelSize(R.dimen.shortcut_size)

        // Calcula a margem esquerda e superior para centralizar o ícone exatamente sob o cursor do drop
        val params = FrameLayout.LayoutParams(shortcutSize, shortcutSize).apply {
            leftMargin = (x - (shortcutSize / 2)).toInt().coerceAtLeast(0)
            topMargin = (y - (shortcutSize / 2)).toInt().coerceAtLeast(0)
        }

        // Adiciona à árvore de visualização do container do Workspace
        desktopShortcutsContainer.addView(shortcutView, params)

        // IMPORTANTE: Em ambiente de produção, este atalho deve ser salvo localmente.
        // ex: databaseHelper.saveShortcut(packageName, className, label, params.leftMargin, params.topMargin)
    }
}

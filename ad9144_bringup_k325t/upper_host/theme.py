"""Dark theme styling for the AD9144 upper-computer UI."""

from __future__ import annotations

from PySide6.QtGui import QColor, QPalette
from PySide6.QtWidgets import QApplication


ACCENT = "#5bd0ff"
GOOD = "#3ecf8e"
WARN = "#f0b84b"
BAD = "#ff6b6b"
BG = "#0f141a"
PANEL = "#151d26"
PANEL_2 = "#18212c"
LINE = "#2a3644"
TEXT = "#e7eef7"
SUBTEXT = "#94a3b8"


def apply_theme(app: QApplication) -> None:
    palette = QPalette()
    palette.setColor(QPalette.Window, QColor(BG))
    palette.setColor(QPalette.WindowText, QColor(TEXT))
    palette.setColor(QPalette.Base, QColor("#0c1117"))
    palette.setColor(QPalette.AlternateBase, QColor(PANEL))
    palette.setColor(QPalette.ToolTipBase, QColor(TEXT))
    palette.setColor(QPalette.ToolTipText, QColor(TEXT))
    palette.setColor(QPalette.Text, QColor(TEXT))
    palette.setColor(QPalette.Button, QColor(PANEL))
    palette.setColor(QPalette.ButtonText, QColor(TEXT))
    palette.setColor(QPalette.BrightText, QColor(TEXT))
    palette.setColor(QPalette.Highlight, QColor(ACCENT))
    palette.setColor(QPalette.HighlightedText, QColor("#001018"))
    app.setPalette(palette)
    app.setStyleSheet(
        f"""
        QWidget {{
            color: {TEXT};
            background: {BG};
            font-family: "Segoe UI";
            font-size: 10.5pt;
            letter-spacing: 0px;
        }}
        QMainWindow::separator {{
            background: {LINE};
            width: 1px;
            height: 1px;
        }}
        QFrame#TopBar {{
            background: {PANEL};
            border-bottom: 1px solid {LINE};
        }}
        QFrame#Card {{
            background: {PANEL};
            border: 1px solid {LINE};
            border-radius: 8px;
        }}
        QFrame#SubCard {{
            background: {PANEL_2};
            border: 1px solid {LINE};
            border-radius: 8px;
        }}
        QLabel#SectionTitle {{
            font-size: 14pt;
            font-weight: 600;
        }}
        QLabel#Hint {{
            color: {SUBTEXT};
        }}
        QLabel#MetricValue {{
            font-size: 18pt;
            font-weight: 700;
        }}
        QLabel#MetricLabel {{
            color: {SUBTEXT};
            text-transform: uppercase;
            letter-spacing: 0px;
        }}
        QLabel#Pill {{
            padding: 4px 8px;
            border-radius: 12px;
            border: 1px solid {LINE};
            background: {PANEL_2};
        }}
        QLabel#Pill[on="true"] {{
            background: rgba(62, 207, 142, 0.18);
            color: #9af0c7;
            border-color: rgba(62, 207, 142, 0.5);
        }}
        QLabel#Pill[warn="true"] {{
            background: rgba(240, 184, 75, 0.18);
            color: #ffd78f;
            border-color: rgba(240, 184, 75, 0.5);
        }}
        QLabel#Pill[bad="true"] {{
            background: rgba(255, 107, 107, 0.18);
            color: #ffb1b1;
            border-color: rgba(255, 107, 107, 0.5);
        }}
        QPushButton {{
            background: #1f2a36;
            border: 1px solid #344456;
            border-radius: 6px;
            padding: 7px 12px;
        }}
        QPushButton:hover {{
            border-color: {ACCENT};
            background: #243244;
        }}
        QPushButton:pressed {{
            background: #16202b;
        }}
        QPushButton:disabled {{
            color: #6d7b8b;
            background: #18212c;
        }}
        QToolButton {{
            background: #1f2a36;
            border: 1px solid #344456;
            border-radius: 6px;
            padding: 5px 9px;
        }}
        QToolButton:hover {{
            border-color: {ACCENT};
        }}
        QLineEdit, QDoubleSpinBox, QSpinBox, QComboBox, QPlainTextEdit, QTextBrowser, QTableWidget {{
            background: #0d141b;
            border: 1px solid #314052;
            border-radius: 6px;
            selection-background-color: {ACCENT};
        }}
        QLineEdit:focus, QDoubleSpinBox:focus, QSpinBox:focus, QComboBox:focus {{
            border-color: {ACCENT};
        }}
        QTableWidget::item:selected {{
            background: rgba(91, 208, 255, 0.25);
        }}
        QHeaderView::section {{
            background: {PANEL_2};
            border: 0px;
            border-bottom: 1px solid {LINE};
            padding: 6px 8px;
            font-weight: 600;
        }}
        QTabWidget::pane {{
            border: 1px solid {LINE};
            border-radius: 6px;
        }}
        QTabBar::tab {{
            background: #18212c;
            border: 1px solid #304050;
            padding: 8px 14px;
            margin-right: 2px;
            border-top-left-radius: 6px;
            border-top-right-radius: 6px;
        }}
        QTabBar::tab:selected {{
            background: #223041;
            border-color: {ACCENT};
        }}
        QListWidget {{
            background: {PANEL};
            border: 1px solid {LINE};
            border-radius: 8px;
        }}
        QListWidget::item {{
            padding: 10px 12px;
            margin: 2px 4px;
            border-radius: 6px;
        }}
        QListWidget::item:selected {{
            background: rgba(91, 208, 255, 0.2);
            color: {TEXT};
        }}
        QScrollBar:vertical {{
            background: transparent;
            width: 12px;
            margin: 12px 2px 12px 2px;
        }}
        QScrollBar::handle:vertical {{
            background: #425365;
            min-height: 24px;
            border-radius: 5px;
        }}
        QScrollBar::handle:vertical:hover {{
            background: {ACCENT};
        }}
        QScrollBar::add-line:vertical, QScrollBar::sub-line:vertical {{
            height: 0px;
        }}
        """
    )


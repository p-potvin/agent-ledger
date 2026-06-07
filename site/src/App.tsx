import { Routes, Route, Navigate } from 'react-router-dom';
import { Shell } from './components/Shell';
import { WorkImpactPage } from './pages/WorkImpactPage';
import { ChangesPage } from './pages/ChangesPage';
import { InputTrackerPage } from './pages/InputTrackerPage';
import { LangProvider } from './i18n';

export function App() {
  return (
    <LangProvider>
      <Shell>
        <Routes>
          <Route path="/" element={<Navigate to="/work-impact" replace />} />
          <Route path="/work-impact" element={<WorkImpactPage />} />
          <Route path="/changes" element={<ChangesPage />} />
          <Route path="/input-tracker" element={<InputTrackerPage />} />
        </Routes>
      </Shell>
    </LangProvider>
  );
}

import { Routes, Route, Navigate } from 'react-router-dom';
import { Shell } from './components/Shell';
import { WorkImpactPage } from './pages/WorkImpactPage';
import { ChangesPage } from './pages/ChangesPage';

export function App() {
  return (
    <Shell>
      <Routes>
        <Route path="/" element={<Navigate to="/work-impact" replace />} />
        <Route path="/work-impact" element={<WorkImpactPage />} />
        <Route path="/changes" element={<ChangesPage />} />
      </Routes>
    </Shell>
  );
}

"use client";

import { motion } from "framer-motion";

type MotionListItemProps = {
  index: number;
  className?: string;
  children: React.ReactNode;
};

export function MotionListItem({ index, className = "", children }: MotionListItemProps) {
  return (
    <motion.div
      className={className}
      initial={{ opacity: 0, y: 10 }}
      animate={{ opacity: 1, y: 0 }}
      transition={{
        delay: Math.min(index * 0.045, 0.35),
        duration: 0.28,
        ease: [0.25, 0.46, 0.45, 0.94],
      }}
    >
      {children}
    </motion.div>
  );
}

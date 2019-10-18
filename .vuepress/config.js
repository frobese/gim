module.exports = {
    title: 'Gim',
    description: 'Graphs In-Memory.',
    base: "/",
    dest: "priv/static",
    patterns: ['*.md'],
    markdown: {
        linkify: true
    },
    themeConfig: {
        displayAllHeaders: true,
        sidebar: [
            ['/', 'Overview'],
        ]
    }
};
